<template>
  <k-field v-bind="$attrs" class="query-field">
    <div ref="container" class="container">
      <pre
        ref="editor"
        spellcheck="false"
        :contenteditable="plaintextOnlySupport ? 'plaintext-only' : 'true'"
        class="editor"
        @input="onInput($event.target.innerText)"
        @keydown.tab.prevent="tabPress"
        @keypress.enter.prevent="enterPress"
      />
      <pre ref="styled" class="styled" />
    </div>

    <pre v-if="error && value" class="error" v-html="error" />
  </k-field>
</template>

<script>
import parser from "../parser/parser";

function supportsPlaintextEditables() {
  const div = document.createElement("div");
  div.setAttribute("contenteditable", "plaintext-only");
  return div.contentEditable === "plaintext-only";
}

function nodeToStr(node) {
  switch (node[0]) {
    case "id":
      return node[1];
    case "val":
      switch (typeof node[1]) {
        case "string":
          return `${node[2]}${node[1]}${node[2]}`;
        case "number":
          return node[1];
        case "boolean":
          return node[1] ? "true" : "false";
        // KQL treats `object`, `array` and `null` as `object`
        case "object":
          return node[1] === null
            ? "null"
            : `[${node[1].map(nodeToStr).join(", ")}]`;
      }
      break;
    case "access":
      return node[1].map(nodeToStr).join(".");
    case "method":
      if (node[1][1].length) {
        return `${nodeToStr(node[1][0])}(${node[1][1]
          .map(nodeToStr)
          .join(", ")})`;
      } else {
        return nodeToStr(node[1][0]);
      }
    case "subscript":
      return `${nodeToStr(node[1][0])}[${nodeToStr(node[1][1])}]`;
  }

  return "";
}

function outdent(lines) {
  return lines.map((line) => {
    return line.replace(/^\s{1,2}/g, "");
  });
}

function indent(lines) {
  return lines.map((line) => {
    return "  " + line;
  });
}

export default {
  props: {
    value: {
      type: Object,
      default() {
        return {
          literal: "",
          clean: "",
        };
      },
    },
  },

  data() {
    return {
      error: null,
      styledHtml: null,
      observer: null,
      plaintextOnlySupport: supportsPlaintextEditables(),
    };
  },

  watch: {
    value(val) {
      if (val && val.literal) {
        this.parse(val.literal || "");
        if (this.$refs.editor.innerText !== val.literal) {
          this.setText(val.literal);
        }
      }
    },
  },

  mounted() {
    const observer = new ResizeObserver(([entry]) => {
      if (this.$refs.container) {
        const h = entry.borderBoxSize[0].blockSize;

        this.$refs.container.style.height = `${h}px`;
      }
    });
    observer.observe(this.$refs.editor);
    this.observer = observer;

    if (this.value) {
      this.setText(this.value.literal || "");
      this.parse(this.value.literal);
    }
  },

  beforeDestroy() {
    this.observer.disconnect();
  },

  methods: {
    select(selectionStart, selectionEnd) {
      const range = document.createRange();
      range.setStart(this.$refs.editor.firstChild, selectionStart);
      range.setEnd(
        this.$refs.editor.firstChild,
        selectionEnd || selectionStart
      );
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
    },

    setText(text, selectionStart, selectionEnd) {
      this.$refs.editor.innerHTML = "";
      this.$refs.editor.appendChild(document.createTextNode(text));

      if (selectionStart) {
        this.select(selectionStart, selectionEnd);
      }
    },

    tabPress(event) {
      const selection = window.getSelection();
      const range = selection.getRangeAt(0);
      const allNodes = Array.from(this.$refs.editor.childNodes).filter(
        (n) => n.nodeType === Node.TEXT_NODE
      );
      const lines = this.$refs.editor.textContent.split("\n");

      const beforeNodes =
        range.startContainer.nodeType === Node.TEXT_NODE
          ? allNodes.slice(0, allNodes.indexOf(range.startContainer))
          : [];
      const nodeBefore = range.startContainer.textContent.substr(
        0,
        range.startOffset
      );

      const beforeText =
        beforeNodes.map((n) => n.textContent).join("") + nodeBefore;

      const selectedText = range.toString();

      const startLine = beforeText.split("\n").length - 1;
      let endLine = (beforeText + selectedText).split("\n").length;
      const affectedLines = lines.slice(startLine, endLine);

      let startColumn = beforeText.split("\n").slice(-1)[0].length;
      let endColumn = (beforeText + selectedText)
        .split("\n")
        .slice(-1)[0].length;
      if (endColumn === 0 && affectedLines.length > 1) {
        affectedLines.pop();
        endColumn = affectedLines[affectedLines.length - 1].length;
        endLine -= 1;
      }

      if (
        (affectedLines.length === 1 &&
          affectedLines[0].length > selectedText.length) ||
        affectedLines[0].length === 0
      ) {
        if (event.shiftKey) {
          const newLine = outdent(affectedLines)[0];
          const delta = newLine.length - lines[startLine].length;
          lines[startLine] = newLine;
          startColumn = startColumn + delta;
          endColumn = endColumn + delta;
        } else {
          lines[startLine] =
            lines[startLine].substr(0, startColumn) +
            "  " +
            lines[startLine].substr(endColumn);
          startColumn = startColumn + 2;
          endColumn = startColumn;
        }
      } else {
        const newLines = event.shiftKey
          ? outdent(affectedLines)
          : indent(affectedLines);

        const deltaStartRow = newLines[0].length - affectedLines[0].length;
        const deltaEndRow =
          newLines[newLines.length - 1].length -
          affectedLines[affectedLines.length - 1].length;
        lines.splice(startLine, newLines.length, ...newLines);

        if (affectedLines.length === 1) {
          startColumn = 0;
        } else {
          startColumn += deltaStartRow;
          startColumn = Math.max(startColumn, 0);
        }

        endColumn += deltaEndRow;
      }

      const startOffset =
        lines.slice(0, startLine).join("\n").length + 1 + startColumn;
      const endOffset =
        lines.slice(0, endLine - 1).join("\n").length + 1 + endColumn;

      const newText = lines.join("\n");
      this.setText(newText, startOffset, endOffset);
      this.onInput(newText);
    },

    enterPress() {
      const selection = window.getSelection();
      const range = selection.getRangeAt(0);
      const allNodes = Array.from(this.$refs.editor.childNodes).filter(
        (n) => n.nodeType === Node.TEXT_NODE
      );

      const beforeNodes =
        range.startContainer.nodeType === Node.TEXT_NODE
          ? allNodes.slice(0, allNodes.indexOf(range.startContainer))
          : [];
      const nodeBefore = range.startContainer.textContent.substr(
        0,
        range.startOffset
      );

      const afterNodes =
        range.endContainer.nodeType === Node.TEXT_NODE
          ? allNodes.slice(allNodes.indexOf(range.endContainer) + 1)
          : [];
      const nodeAfter = range.endContainer.textContent.substr(range.endOffset);

      const beforeText =
        beforeNodes.map((n) => n.textContent).join("") + nodeBefore;
      const afterText =
        nodeAfter + afterNodes.map((n) => n.textContent).join("");

      const startLine = beforeText.split("\n").pop();

      const indentCount = startLine.match(/^\s*/)[0].length;

      const newLine = "\n" + new Array(indentCount + 1).join(" ");
      const newText =
        beforeText +
        newLine +
        (afterText.endsWith("\n") ? afterText : afterText + "\n");
      console.log(newLine.length);
      this.setText(newText, beforeText.length + newLine.length);
      this.onInput(newText);
    },

    focus() {
      this.select(this.$refs.editor.firstChild.length);
    },

    parse(text) {
      const fragment = document.createDocumentFragment();

      this.$refs.styled.innerHTML = "";

      if (text.trim()) {
        let cur = 0;

        try {
          parser.onShift = (token) => {
            if (token.startOffset > cur) {
              fragment.appendChild(
                document.createTextNode(text.slice(cur, token.startOffset))
              );
            }

            const span = document.createElement("span");
            span.appendChild(
              document.createTextNode(
                text.slice(token.startOffset, token.endOffset)
              )
            );
            span.className = "color-" + token.type.toLocaleLowerCase();

            fragment.appendChild(span);

            cur = token.endOffset;
            return token;
          };

          const ast = parser.parse(text, { captureLocations: true });
          this.error = null;

          this.$refs.styled.appendChild(fragment);

          return {
            literal: text,
            clean: nodeToStr(ast),
          };
        } catch (err) {
          this.ast = null;

          fragment.appendChild(document.createTextNode(text.slice(cur)));
          this.$refs.styled.appendChild(fragment);
          this.error = err;

          return {
            literal: text,
            clean: "",
          };
        }
      } else {
        this.error = null;

        return {
          literal: "",
          clean: "",
        };
      }
    },

    onInput(text) {
      this.$nextTick(() => {
        this.$emit("input", this.parse(text));
      });
    },
  },
};
</script>

<style>
.query-field .container {
  position: relative;
  background: var(--color-background);
  overflow-x: auto;
  overflow-y: hidden;
}

.query-field .container > * {
  padding: 1rem;
}

.query-field .error {
  color: var(--color-negative);
  margin-top: 0.5rem;
}

.query-field .editor {
  color: transparent;
  caret-color: var(--color-base);
  min-height: 3rem;
  outline: none;
}

.query-field .editor::selection {
  color: transparent;
  background: var(--color-selection-bg);
}

.query-field .styled {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  color: var(--color-base);
  font-family: monospace;
  pointer-events: none;
  min-height: 3rem;
}

.query-field span.color-identifier {
  color: var(--color-identifier);
}
.query-field span.color-string1 {
  color: var(--color-string1);
}
.query-field span.color-string2 {
  color: var(--color-string2);
}
.query-field span.color-float {
  color: var(--color-num);
}
.query-field span.color-int {
  color: var(--color-num);
}
.query-field span.color-true {
  color: var(--color-bool);
}
.query-field span.color-false {
  color: var(--color-bool);
}
.query-field span.color-dot {
  color: var(--color-dot);
}
.query-field span.color-null {
  color: var(--color-null);
}
.query-field span.color-lparen,
.query-field span.color-rparen {
  color: var(--color-round-brackets);
}
.query-field span.color-lbracket,
.query-field span.color-rbracket {
  color: var(--color-square-brackets);
}

.query-field {
  --color-background: #333;
  --color-base: #eee;
  --color-identifier: #7e9abf;
  --color-string1: #de935f;
  --color-string2: #de935f;
  --color-bool: #a7bd68;
  --color-num: #a7bd68;
  --color-null: #a7bd68;
  --color-selection-bg: rgba(244, 244, 244, 0.2);
}
</style>

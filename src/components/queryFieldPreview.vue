<template>
  <pre class="k-structure-table-text">{{value.clean}}</pre>
</template>

<script>
export default {
  props: {
    value: String,
    column: Object,
    field: Object
  }
}
</script>

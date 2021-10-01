import Query from "./components/Query.vue";
import QueryFieldPreview from "./components/QueryFieldPreview.vue";

window.panel.plugin("rasteiner/k3-query-field", {
  fields: {
    Query,
  },
  components: {
    "k-query-field-preview": QueryFieldPreview,
  },
});

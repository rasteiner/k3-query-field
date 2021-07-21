import query from './components/query.vue'
import queryFieldPreview from './components/queryFieldPreview.vue'

panel.plugin('rasteiner/k3-query-field', {
  fields: {
    query
  },
  components: {
    'k-query-field-preview': queryFieldPreview
  }

})

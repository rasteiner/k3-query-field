<?php
use Kirby\Toolkit\Query;

Kirby::plugin('rasteiner/k3-query-field', [
  'fieldMethods' => [
    'executeQuery' => function($field, $context) {
      if($field->isEmpty()) return null;

      $trimmed = trim($field->value());

      try {
        if($trimmed[0] === '{') {
          $data = json_decode($trimmed, true);
        } else {
          $data = $field->yaml();
        }
      } catch(Exception $e) {
      }

      if(isset($data) && isset($data['clean'])) {
        $str = $data['clean'];
      } else {
        $str = $trimmed;
      }

      $q = new Query($str, $context);

      return $q->result();
    }
  ],
  'fields' => [
    'query' => [
      'computed' => [
        'value' => function() {
          try {
            $data = Data::decode($this->value, 'json');
          } catch(Exception $e) {
            $data = Data::decode($this->value, 'yaml');
          }
          if(!isset($data['literal'])) {
            return [
              'literal' => $this->value,
              'clean' => $this->value
            ];
          }
          return $data;
        }
      ],
      'save' => function($value) {
        return Data::encode($value, 'json');
      }
    ]
  ]
]);
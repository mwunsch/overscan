#lang racket/base

(require (rename-in ffi/unsafe [-> ->>])
         ffi/unsafe/define
         ffi/unsafe/introspection
         racket/contract
         "core.rkt")

(provide (contract-out [gst-structure?
                        (-> any/c boolean?)]
                       [gst-structure-name
                        (-> gst-structure? string?)]
                       [gst-structure-has-name?
                        (-> gst-structure? string? boolean?)]
                       [gst-structure-remove-field
                        (-> gst-structure? string? void?)]
                       [gst-structure-n-fields
                        (-> gst-structure? exact-nonnegative-integer?)]
                       [gst-structure-nth-field-name
                        (-> gst-structure? exact-nonnegative-integer? string?)]
                       [gst-structure-field-names
                        (-> gst-structure? (listof string?))]
                       [gst-structure-has-field?
                        (-> gst-structure? string? boolean?)]
                       [gst-structure-has-field-typed?
                        (-> gst-structure? string? gtype? boolean?)]
                       [gst-structure=?
                        (-> gst-structure? gst-structure? boolean?)]
                       [gst-structure-is-subset?
                        (-> gst-structure? gst-structure? boolean?)]
                       [gst-structure-can-intersect?
                        (-> gst-structure? gst-structure? boolean?)]
                       [gst-structure-intersect
                        (-> gst-structure? gst-structure? gst-structure?)]
                       [gst-structure->string
                        (-> gst-structure? string?)]
                       [gst-structure-get-field-type
                        (-> gst-structure? string? (or/c gtype? zero?))]
                       [gst-structure-ref
                        (-> gst-structure? string?
                            (or/c false/c any/c))]
                       [gst-structure-set!
                        (-> gst-structure? string? any/c
                            void?)]))

(define (gst-structure? v)
  (is-gtype? v gst-structure))

(define (gst-structure-name structure)
  (gobject-send structure 'get_name))

(define (gst-structure-has-name? structure name)
  (gobject-send structure 'has_name name))

(define (gst-structure-remove-field structure fieldname)
  (gobject-send structure 'remove_field fieldname))

(define (gst-structure-n-fields structure)
  (gobject-send structure 'n_fields))

(define (gst-structure-nth-field-name structure index)
  (gobject-send structure 'nth_field_name index))

(define (gst-structure-field-names structure)
  (for/list ([i (in-range (gst-structure-n-fields structure))])
    (gst-structure-nth-field-name structure i)))

(define (gst-structure-has-field? structure fieldname)
  (gobject-send structure 'has_field fieldname))

(define (gst-structure-has-field-typed? structure fieldname type)
  (gobject-send structure 'has_field_typed fieldname type))

(define (gst-structure=? structure1 structure2)
  (gobject-send structure1 'is_equal structure2))

(define (gst-structure-is-subset? subset superset)
  (gobject-send subset 'is_subset superset))

(define (gst-structure-can-intersect? struct1 struct2)
  (gobject-send struct1 'can_intersect struct2))

(define (gst-structure-intersect struct1 struct2)
  (gobject-send struct1 'intersect struct2))

(define (gst-structure->string structure)
  (gobject-send structure 'to_string))

(define (gst-structure-get-field-type structure fieldname)
  (gobject-send structure 'get_field_type fieldname))


(define-gst gst-structure-get (_fun (_gi-struct gst-structure)
                                    _string
                                    [type :  _gtype]
                                    [r : (_ptr o (gtype->ctype type))]
                                    (_pointer = #f)
                                    ->> (found : _bool)
                                    ->> (and found
                                             r))
  #:c-id gst_structure_get)

(define-gst gst-structure-set! (_fun (_gi-struct gst-structure)
                                    _string
                                    _pointer
                                    ->> _void)
  #:c-id gst_structure_set_value)


(define (gst-structure-ref structure key)
  (let* ([type (gst-structure-get-field-type structure key)])
    (and (not (zero? type))
         (gst-structure-get structure key type))))

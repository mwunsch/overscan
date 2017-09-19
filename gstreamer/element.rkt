#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound? is-a? is-a?/c)
         racket/class
         "gst.rkt")

(provide element-factory%
         element%
         element-factory%-find
         element-factory%-make)

(define gst-element-factory (gst 'ElementFactory))

(define element-factory%
  (class gobject%
         (super-new)
         (inherit-field pointer)
         (define/public (get-name)
           (gobject-send pointer 'get_name))
         (define/public (create name)
           (let ([el (gobject-send pointer 'create name)])
             (new element% [pointer el])))
         (define/public (get-metadata)
           (for/hash ([key (gobject-send pointer 'get_metadata_keys)])
                     (values (string->symbol key)
                             (gobject-send pointer 'get_metadata key))))))

(define (element-factory%-find name)
  (let ([factory (gst-element-factory 'find name)])
    (new element-factory% [pointer factory])))

(define (element-factory%-make factory-name name)
  (let ([el (gst-element-factory 'make factory-name name)])
    (new element% [pointer el])))

(define element%
  (class gobject%
    (super-new)
    (inherit-field pointer)
    (define/public (get-factory)
      (let ([fac (gobject-send pointer 'get_factory)])
        (new element-factory% [pointer fac])))))

(define (sink? el)
  (and (zero? (get-field numsrcpads el))
       (positive? (get-field numsinkpads el))))

(define (src? el)
  (not (sink? el)))

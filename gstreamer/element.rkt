#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound? is-a? is-a?/c)
         racket/class
         racket/contract
         "gst.rkt")

(provide (contract-out [element-factory%
                        element-factory%/c]
                       [element%
                        (subclass?/c gst-object%)]
                       [pad%
                        (subclass?/c gst-object%)]
                       [ghost-pad%
                        (subclass?/c pad%)]
                       [element-factory%-find
                        (-> string? (or/c false/c
                                          (instanceof/c element-factory%/c)))]
                       [element-factory%-make
                        (->* (string?)
                             ((or/c string? false/c))
                             (or/c false/c
                                   (is-a?/c element%)))]))

(define gst-element-factory (gst 'ElementFactory))

(define element-factory%
  (class gst-object%
         (super-new)
         (inherit-field pointer)
         (define/public (create [name #f])
           (let ([el (gobject-send pointer 'create name)])
             (new element% [pointer el])))
         (define/public (get-metadata)
           (for/hash ([key (in-vector (gobject-send pointer 'get_metadata_keys))])
                     (values (string->symbol key)
                             (gobject-send pointer 'get_metadata key))))))

(define (element-factory%-find name)
  (let ([factory (gst-element-factory 'find name)])
    (and factory
         (new element-factory% [pointer factory]))))

(define (element-factory%-make factory-name [name #f])
  (let ([el (gst-element-factory 'make factory-name name)])
    (and el
         (new element% [pointer el]))))

(define element-mixin
  (make-gobject-delegate get-compatible-pad
                         get-request-pad
                         get-static-pad
                         link
                         unlink
                         link-pads
                         link-pads-filtered
                         link-filtered
                         get-factory
                         set-state))

(define element%
  (class (element-mixin gst-object%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-static-pad name)
      (let ([static-pad (super get-static-pad name)])
        (and static-pad
             (new pad% [pointer static-pad]))))
    (define/override (get-factory)
      (new element-factory+c% [pointer (super get-factory)]))
    (define/public (get-num-src-pads)
      (gobject-get-field 'numsrcpads pointer))
    (define/public (get-num-sink-pads)
      (gobject-get-field 'numsinkpads pointer))
    (define/public (sink?)
      (and (zero? (get-num-src-pads))
           (positive? (get-num-sink-pads))))
    (define/public (src?)
      (not (sink?)))))

(define pad-mixin
  (make-gobject-delegate get-direction
                         get-parent-element
                         get-pad-template
                         link
                         link-maybe-ghosting
                         unlink
                         [linked? 'is_linked]
                         [can-link? 'can_link]
                         get-allowed-caps
                         get-current-caps
                         get-peer
                         [active? 'is_active]))

(define pad%
  (class (pad-mixin gst-object%)
    (super-new)
    (inherit-field pointer)))

(define ghost-pad%
  (class pad%
    (super-new)
    (inherit-field pointer)))

(define element-factory%/c
  (class/c
   [create
    (->*m () ((or/c string? false/c)) (is-a?/c element%))]
   [get-metadata
    (->m (hash/c symbol? any/c))]))

(define/contract element-factory+c%
  element-factory%/c
  element-factory%)

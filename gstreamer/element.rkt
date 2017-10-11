#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         "gst.rkt"
         "caps.rkt"
         "clock.rkt")

(provide (contract-out [element-factory%
                        element-factory%/c]
                       [element%
                        element%/c]
                       [pad%
                        pad%/c]
                       [ghost-pad%
                        (and/c (subclass?/c pad%)
                               (class/c
                                [get-target
                                 (->m (or/c (instanceof/c pad%/c)
                                            false/c))]
                                [set-target
                                 (->m (is-a?/c pad%) boolean?)]))]
                       [pad-direction
                        gi-enum?]))

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

(define element-mixin
  (make-gobject-delegate add-pad
                         get-compatible-pad
                         get-request-pad
                         get-static-pad
                         link
                         unlink
                         link-pads
                         link-pads-filtered
                         link-filtered
                         get-factory
                         set-state
                         get-state))

(define element%
  (class (element-mixin gst-object%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-static-pad name)
      (let ([static-pad (super get-static-pad name)])
        (and static-pad
             (new pad% [pointer static-pad]))))
    (define/public (link-many el . els)
      (and (send this link el)
           (if (pair? els)
               (send/apply el link-many (car els) (cdr els))
               #t)))
    (define/override (get-factory)
      (new element-factory% [pointer (super get-factory)]))
    (define/override (get-state [timeout clock-time-none])
      (super get-state timeout))
    (define/public (play!)
      (send this set-state 'playing))
    (define/public (pause!)
      (send this set-state 'paused))
    (define/public (stop!)
      (send this set-state 'null))
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
    (inherit-field pointer)
    (define/override (get-parent-element)
      (new element% [pointer (super get-parent-element)]))))

(define ghost-pad-mixin
  (make-gobject-delegate set-target
                         get-target))

(define ghost-pad%
  (class (ghost-pad-mixin pad%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-target)
      (let ([target (super get-target)])
        (and target
             (new pad% [pointer target]))))))

(define pad-link-return
  (gst 'PadLinkReturn))

(define pad-direction
  (gst 'PadDirection))

(define state
  (gst 'State))

(define state-change-return
  (gst 'StateChangeReturn))

(define pad%/c
  (class/c
   [get-direction
    (->m (gi-enum-value/c pad-direction))]
   [get-parent-element
    (->m (is-a?/c element%))]
   get-pad-template
   [link
    (->m (is-a?/c pad%) (gi-enum-value/c pad-link-return))]
   [link-maybe-ghosting
    (->m (is-a?/c pad%) boolean?)]
   [unlink
    (->m (is-a?/c pad%) boolean?)]
   [linked?
    (->m boolean?)]
   [can-link?
    (->m (is-a?/c pad%) boolean?)]
   [get-allowed-caps
    (->m caps?)]
   [get-current-caps
    (->m caps?)]
   [get-peer
    (->m (or/c (is-a?/c pad%) false/c))]
   [active?
    (->m boolean?)]))

(define element%/c
  (class/c
   [add-pad
    (->m (is-a?/c pad%) boolean?)]
   get-compatible-pad
   get-request-pad
   [get-static-pad
    (->m string? (or/c (instanceof/c pad%/c) false/c))]
   [link
    (->m (is-a?/c element%) boolean?)]
   [unlink
    (->m (is-a?/c element%) void?)]
   [link-many
    (->m (is-a?/c element%) (is-a?/c element%) ... boolean?)]
   [link-pads
    (->m (or/c string? false/c) (is-a?/c element%) (or/c string? false/c) boolean?)]
   [link-pads-filtered
    (->m string? (is-a?/c element%) string? (or/c caps? false/c) boolean?)]
   [link-filtered
    (->m (is-a?/c element%) (or/c caps? false/c) boolean?)]
   [get-factory
    (->m (is-a?/c element-factory%))]
   [set-state
    (->m (gi-enum-value/c state) (gi-enum-value/c state-change-return))]
   [get-state
    (->*m ()
          (clock-time?)
          (values (gi-enum-value/c state-change-return)
                 (gi-enum-value/c state)
                 (gi-enum-value/c state)))]))

(define element-factory%/c
  (class/c
   [create
    (->*m () ((or/c string? false/c)) (instanceof/c element%/c))]
   [get-metadata
    (->m (hash/c symbol? any/c))]))

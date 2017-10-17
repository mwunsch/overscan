#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         "gst.rkt"
         "caps.rkt"
         "clock.rkt"
         "event.rkt")

(provide (contract-out [element-factory%
                        element-factory%/c]
                       [element%
                        element%/c]
                       [source?
                        (-> any/c boolean?)]
                       [sink?
                        (-> any/c boolean?)]
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
                        gi-enum?]
                       [pad-presence
                        gi-enum?]
                       [pad-template?
                        (-> any/c boolean?)]
                       [pad-template-caps
                        (-> pad-template? caps?)]
                       [make-pad-template
                        (-> string?
                            (gi-enum-value/c pad-direction)
                            (gi-enum-value/c pad-presence)
                            caps?
                            pad-template?)]))

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
                         get-state
                         send-event))

(define element%
  (class (element-mixin gst-object%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-compatible-pad pad [caps #f])
      (let ([compatible-pad (super get-compatible-pad pad caps)])
        (and compatible-pad
             (new pad% [pointer compatible-pad]))))
    (define/override (get-request-pad name)
      (let ([req-pad (super get-request-pad name)])
        (and req-pad
             (new pad% [pointer req-pad]))))
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
      (send this set-state 'null))))

(define (source? v)
  (and (is-a? v element%)
       (positive? (gobject-get-field 'numsrcpads v))
       (zero? (gobject-get-field 'numsinkpads v))))

(define (sink? v)
  (and (is-a? v element%)
       (positive? (gobject-get-field 'numsinkpads v))
       (zero? (gobject-get-field 'numsrcpads v))))

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
                         get-pad-template-caps
                         get-peer
                         [has-current-caps? 'has_current_caps]
                         [active? 'is_active]
                         [blocked? 'is_blocked]
                         [blocking? 'is_blocking]))

(define pad%
  (class (pad-mixin gst-object%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-parent-element)
      (new element% [pointer (super get-parent-element)]))
    (define/override (get-peer)
      (let ([peer (super get-peer)])
        (and peer
             (new pad% [pointer peer]))))))

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

(define pad-presence
  (gst 'PadPresence))

(define state
  (gst 'State))

(define state-change-return
  (gst 'StateChangeReturn))

(define gst-pad-template
  (gst 'PadTemplate))

(define (pad-template? v)
  (is-gtype? v gst-pad-template))

(define (pad-template-caps template)
  (gobject-send template 'get_caps))

(define (make-pad-template name dir presence caps)
  (gst-pad-template 'new name dir presence caps))

(define pad%/c
  (class/c
   [get-direction
    (->m (gi-enum-value/c pad-direction))]
   [get-parent-element
    (->m (is-a?/c element%))]
   [get-pad-template
    (->m (or/c pad-template? false/c))]
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
   [get-pad-template-caps
    (->m caps?)]
   [get-peer
    (->m (or/c (is-a?/c pad%) false/c))]
   [has-current-caps?
    (->m boolean?)]
   [active?
    (->m boolean?)]
   [blocked?
    (->m boolean?)]
   [blocking?
    (->m boolean?)]))

(define element%/c
  (class/c
   [add-pad
    (->m (is-a?/c pad%) boolean?)]
   [get-compatible-pad
    (->*m ((is-a?/c pad%))
          ((or/c caps? false/c))
          (or/c (instanceof/c pad%/c) false/c))]
   [get-request-pad
    (->m string? (or/c (instanceof/c pad%/c) false/c))]
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
                  (gi-enum-value/c state)))]
   [send-event
    (->m event? boolean?)]))

(define element-factory%/c
  (class/c
   [create
    (->*m () ((or/c string? false/c)) (instanceof/c element%/c))]
   [get-metadata
    (->m (hash/c symbol? any/c))]))

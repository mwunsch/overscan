#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/caps
         gstreamer/element
         gstreamer/bus)

(provide (contract-out [device-monitor%
                        (class/c
                         [get-bus
                          (->m (is-a?/c bus%))]
                         [add-filter
                          (->m (or/c string? false/c) (or/c caps? false/c) exact-integer?)]
                         [remove-filter
                          (->m exact-integer? boolean?)]
                         [get-devices
                          (->m (listof (instanceof/c device%/c)))])]
                       [device%
                        device%/c]))

(define device-monitor-mixin
  (make-gobject-delegate get-bus
                         add-filter
                         remove-filter
                         get-devices))

(define device-monitor%
  (class (device-monitor-mixin gobject%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-bus)
      (new bus% [pointer (super get-bus)]))
    (define/override (get-devices)
      (map (lambda (device) (new device% [pointer device])) (super get-devices)))))

(define device-mixin
  (make-gobject-delegate create-element
                         get-caps
                         get-device-class
                         get-display-name
                         [has-classes? 'has_classes]))

(define device%
  (class (device-mixin gobject%)
    (super-new)
    (inherit-field pointer)
    (define/override (create-element [name #f])
      (let ([el (super create-element name)])
        (gobject-send el 'ref_sink)
        (new element% [pointer el])))))

(define device%/c
  (class/c
   [create-element
    (->*m () ((or/c string? false/c)) (is-a?/c element%))]
   [get-caps
    (->m caps?)]
   [get-device-class
    (->m string?)]
   [get-display-name
    (->m string?)]
   [has-classes?
    (->m string? boolean?)]))

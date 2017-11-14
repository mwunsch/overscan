#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst)

(provide (contract-out [device-monitor%
                        (class/c
                         get-bus
                         add-filter
                         remove-filter
                         get-devices)]
                       [device%
                        (class/c
                         create-element
                         get-caps
                         get-device-class
                         get-display-name
                         has-classes?)]))

(define device-monitor-mixin
  (make-gobject-delegate get-bus
                         add-filter
                         remove-filter
                         get-devices))

(define device-monitor%
  (class (device-monitor-mixin gobject%)
    (super-new)
    (inherit-field pointer)))

(define device-mixin
  (make-gobject-delegate create-element
                         get-caps
                         get-device-class
                         get-display-name
                         [has-classes? 'has_classes]))

(define device%
  (class (device-mixin gobject%)
    (super-new)
    (inherit-field pointer)))

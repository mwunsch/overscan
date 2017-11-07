#lang racket/base

(require ffi/unsafe/introspection
         (only-in ffi/unsafe _string)
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/caps
         gstreamer/element
         gstreamer/factories)

(provide (contract-out [capsfilter
                        (->* (caps?)
                             ((or/c string? false/c))
                             capsfilter?)]
                       [capsfilter?
                        (-> any/c boolean?)]
                       [capsfilter-caps
                        (-> capsfilter? caps?)]
                       [tee
                        (->* ()
                             ((or/c string? false/c))
                             tee?)]
                       [tee?
                        (-> any/c boolean?)]
                       [rtmpsink
                        (->* (string?)
                             ((or/c string? false/c))
                             rtmpsink?)]
                       [rtmpsink?
                        (-> any/c boolean?)]
                       [rtmpsink-location
                        (-> rtmpsink? string?)]))

(define (capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))

(define capsfilter?
  (element/c "capsfilter"))

(define (capsfilter-caps element)
  (gobject-get element "caps" (gst 'Caps)))

(define (tee [name #f])
  (element-factory%-make "tee" name))

(define tee?
  (element/c "tee"))

(define (rtmpsink location [name #f])
  (gobject-with-properties (element-factory%-make "rtmpsink" name)
                           (hash 'location location)))

(define rtmpsink?
  (element/c "rtmpsink"))

(define (rtmpsink-location element)
  (gobject-get element "location" _string))

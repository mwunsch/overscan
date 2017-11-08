#lang racket/base

(require ffi/unsafe/introspection
         (only-in ffi/unsafe _string _bool)
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
                        (-> rtmpsink? string?)]
                       [videotestsrc
                        (->* ()
                             ((or/c string? false/c)
                              #:pattern videotest-pattern/c
                              #:live? boolean?)
                             videotestsrc?)]
                       [videotestsrc?
                        (-> any/c boolean?)]
                       [videotestsrc-pattern
                        (-> videotestsrc? videotest-pattern/c)]
                       [set-videotestsrc-pattern!
                        (-> videotestsrc? videotest-pattern/c void?)]
                       [videotestsrc-live?
                        (-> videotestsrc? boolean?)]
                       [videotest-pattern/c
                        flat-contract?]))

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

(define videotest-patterns
  '(smpte snow black white red green blue
          checkers-1 checkers-2 checkers-4 checkers-8
          circular blink smpte75 zone-plate gamut
          chroma-zone-plate solid-color ball smpte100 bar
          pinwheel spokes gradient colors))

(define videotest-pattern/c
  (apply one-of/c videotest-patterns))

(define (videotestsrc [name #f]
                      #:pattern [pattern 'smpte]
                      #:live? [live? #f])
  (let ([el (element-factory%-make "videotestsrc" name)])
    (gobject-set! el "pattern" pattern videotest-patterns)
    (gobject-set! el "is-live" live? _bool)
    el))

(define videotestsrc?
  (element/c "videotestsrc"))

(define (videotestsrc-pattern element)
  (gobject-get element "pattern" videotest-patterns))

(define (set-videotestsrc-pattern! element pattern)
  (gobject-set! element "pattern" pattern videotest-patterns))

(define (videotestsrc-live? element)
  (gobject-get element "is-live" _bool))

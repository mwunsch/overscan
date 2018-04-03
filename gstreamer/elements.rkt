#lang racket/base

(require ffi/unsafe/introspection
         (only-in ffi/unsafe _string _bool _int _double)
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
                       [set-capsfilter-caps!
                        (-> capsfilter? caps? void?)]
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
                        flat-contract?]
                       [videomixer
                        (->* ()
                             ((or/c string? false/c))
                             videomixer?)]
                       [videomixer?
                        (-> any/c boolean?)]
                       [videomixer-background
                        (-> videomixer? symbol?)]
                       [set-videomixer-background!
                        (-> videomixer? symbol? void?)]
                       [videomixer-ref
                        (-> videomixer?
                            exact-nonnegative-integer?
                            (or/c (is-a?/c pad%)
                                  false/c))]
                       [videobox
                        (->* ()
                             ((or/c string? false/c)
                              #:autocrop? boolean?
                              #:top exact-integer?
                              #:bottom exact-integer?
                              #:left exact-integer?
                              #:right exact-integer?)
                             videobox?)]
                       [videobox-alpha
                        (-> videobox? (real-in 0 1))]
                       [set-videobox-alpha!
                        (-> videobox? (real-in 0 1) void?)]
                       [videobox?
                        (-> any/c boolean?)]
                       [videoscale
                        (->* ()
                             ((or/c string? false/c))
                             videoscale?)]
                       [videoscale?
                        (-> any/c boolean?)]))

(define (capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))

(define capsfilter?
  (element/c "capsfilter"))

(define-values (capsfilter-caps set-capsfilter-caps!)
  (make-gobject-property-procedures "caps" (gst 'Caps)))

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
                      #:live? [live? #t])
  (let ([el (element-factory%-make "videotestsrc" name)])
    (gobject-set! el "pattern" pattern videotest-patterns)
    (gobject-set! el "is-live" live? _bool)
    el))

(define videotestsrc?
  (element/c "videotestsrc"))

(define-values (videotestsrc-pattern set-videotestsrc-pattern!)
  (make-gobject-property-procedures "pattern" videotest-patterns))

(define (videotestsrc-live? element)
  (gobject-get element "is-live" _bool))

(define (videomixer [name #f])
  (element-factory%-make "videomixer" name))

(define videomixer?
  (element/c "videomixer"))

(define-values (videomixer-background set-videomixer-background!)
  (make-gobject-property-procedures "background"
                                    '(checker black white transparent)))

(define (videomixer-ref mixer pos)
  (let ([pad (format "sink_~a" pos)])
    (send mixer get-static-pad pad)))

(define (videobox [name #f]
                  #:autocrop? [autocrop #f]
                  #:top [top 0]
                  #:right [right 0]
                  #:bottom [bottom 0]
                  #:left [left 0])
  (let ([el (element-factory%-make "videobox" name)])
    (gobject-set! el "top" top _int)
    (gobject-set! el "right" right _int)
    (gobject-set! el "bottom" bottom _int)
    (gobject-set! el "left" left _int)
    (gobject-set! el "autocrop" autocrop _bool)
    el))

(define-values (videobox-alpha set-videobox-alpha!)
  (make-gobject-property-procedures "alpha"
                                    _double))

(define videobox?
  (element/c "videobox"))

(define (videoscale [name #f])
  (element-factory%-make "videoscale" name))

(define videoscale?
  (element/c "videoscale"))

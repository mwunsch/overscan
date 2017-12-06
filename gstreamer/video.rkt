#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/buffer
         gstreamer/caps)

(provide (contract-out [video-meta?
                        (-> any/c boolean?)]
                       [video-info?
                        (-> any/c boolean?)]
                       [buffer-video-meta
                        (-> buffer?
                            (or/c video-meta? false/c))]
                       [video-meta-dimensions
                        (-> video-meta?
                            (values exact-nonnegative-integer?
                                    exact-nonnegative-integer?))]
                       [video-meta-format
                        (-> video-meta?
                            (gi-enum-value/c gst-video-format))]
                       [caps->video-info
                        (-> caps? (or/c video-info? false/c))]))

(define gst-video
  (introspection 'GstVideo))

(define gst-video-meta
  (gst-video 'VideoMeta))

(define gst-video-info
  (gst-video 'VideoInfo))

(define gst-video-format
  (gst-video 'VideoFormat))

(define (video-meta? v)
  (is-gtype? v gst-video-meta))

(define (video-info? v)
  (is-gtype? v gst-video-info))

(define buffer-video-meta
  (gst-video 'buffer_get_video_meta))

(define (video-meta-dimensions meta)
  (values (gobject-get-field 'width meta)
          (gobject-get-field 'height meta)))

(define (video-meta-format meta)
  (gobject-get-field 'format meta))

(define (caps->video-info caps)
  (let ([info (gst-video-info 'new)])
    (and (gst-video-info 'from_caps info caps)
         info)))

#lang racket/base

(require (rename-in ffi/unsafe [-> ~>])
         ffi/unsafe/define
         ffi/unsafe/alloc
         ffi/unsafe/introspection
         ffi/vector
         racket/class
         racket/contract
         (only-in "private/core.rkt" gst-caps gst-buffer gst-map-flags)
         gstreamer/gst
         gstreamer/buffer
         gstreamer/caps)

(provide (contract-out [video-meta?
                        (-> any/c boolean?)]
                       [video-info?
                        (-> any/c boolean?)]
                       [video-format-info?
                        (-> any/c boolean?)]
                       [_video-info
                        ctype?]
                       [_video-info-pointer
                        ctype?]
                       [_video-format-info
                        ctype?]
                       [_video-format-info-pointer
                        ctype?]
                       [video-format-info-name
                        (-> video-format-info? string?)]
                       [video-format-info-description
                        (-> video-format-info? string?)]
                       [video-format-info-flags
                        (-> video-format-info? (listof symbol?))]
                       [video-format-info-unpack-format
                        (-> video-format-info? (gi-enum-value/c gst-video-format))]
                       [video-format-info-n-components
                        (-> video-format-info? exact-nonnegative-integer?)]
                       [video-format-info-shift
                        (-> video-format-info? vector?)]
                       [video-format-info-depth
                        (-> video-format-info? vector?)]
                       [video-format-info-pixel-stride
                        (-> video-format-info? vector?)]
                       [video-format-info-n-planes
                        (-> video-format-info? exact-nonnegative-integer?)]
                       [video-format-info-plane
                        (-> video-format-info? vector?)]
                       [video-format-info-poffset
                        (-> video-format-info? vector?)]
                       [video-info-flags
                        (-> video-info? (gi-bitmask-value/c gst-video-flags))]
                       [video-info-width
                        (-> video-info? exact-nonnegative-integer?)]
                       [video-info-height
                        (-> video-info? exact-nonnegative-integer?)]
                       [video-info-size
                        (-> video-info? exact-nonnegative-integer?)]
                       [video-info-par
                        (-> video-info? rational?)]
                       [video-info-fps
                        (-> video-info? rational?)]
                       [video-info-finfo
                        (-> video-info? video-format-info?)]
                       [video-info-offset
                        (-> video-info? vector?)]
                       [video-info-stride
                        (-> video-info? vector?)]
                       [video-frame?
                        (-> any/c boolean?)]
                       [_video-frame
                        ctype?]
                       [_video-frame-pointer
                        ctype?]
                       [video-frame-id
                        (-> video-frame? exact-integer?)]
                       [video-frame-data
                        (-> video-frame? array?)]
                       [video-frame-mapping
                        (-> video-frame? array?)]
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
                        (-> caps? (or/c video-info? false/c))]
                       [video-info->caps
                        (-> video-info? caps?)]
                       [video-frame-map
                        (-> video-info?
                            buffer?
                            map-flags?
                            (or/c video-frame? false/c))]
                       [video-frame-unmap!
                        (-> video-frame? void?)]
                       [video-frame-planes
                        (-> video-frame? (vectorof cpointer?))]))

(define gst-video
  (introspection 'GstVideo))

(define gst-video-meta
  (gst-video 'VideoMeta))

(define gst-video-format
  (gst-video 'VideoFormat))

(define gst-video-format-flags
  (gst-video 'VideoFormatFlags))

(define gst-video-interlace-mode
  (gst-video 'VideoInterlaceMode))

(define gst-video-flags
  (gst-video 'VideoFlags))

(define gst-video-chroma-site
  (gst-video 'VideoChromaSite))

(define gst-video-color-range
  (gst-video 'VideoColorRange))

(define gst-video-color-matrix
  (gst-video 'VideoColorMatrix))

(define gst-video-transfer-function
  (gst-video 'VideoTransferFunction))

(define gst-video-color-primaries
  (gst-video 'VideoColorPrimaries))

(define gst-video-frame-flags
  (gst-video 'VideoFrameFlags))

(define VIDEO-MAX-PLANES
  ((gst-video 'VIDEO_MAX_PLANES)))

(define VIDEO-MAX-COMPONENTS
  ((gst-video 'VIDEO_MAX_COMPONENTS)))

(define-ffi-definer define-gst-video
  (gi-repository->ffi-lib gst-video))

(define (video-meta? v)
  (is-gtype? v gst-video-meta))

(define buffer-video-meta
  (gst-video 'buffer_get_video_meta))

(define (video-meta-dimensions meta)
  (values (gobject-get-field 'width meta)
          (gobject-get-field 'height meta)))

(define (video-meta-format meta)
  (gobject-get-field 'format meta))

(define-cstruct _colorimetry ([range (_gi-enum gst-video-color-range)]
                              [matrix (_gi-enum gst-video-color-matrix)]
                              [transfer (_gi-enum gst-video-transfer-function)]
                              [primaries (_gi-enum gst-video-color-primaries)]))

(define-cstruct _video-format-info ([format (_gi-enum gst-video-format)]
                                    [name _string]
                                    [description _string]
                                    [flags (_gi-enum gst-video-format-flags)]
                                    [bits _uint]
                                    [n-components _uint]
                                    [shift (_array/vector _uint VIDEO-MAX-COMPONENTS)]
                                    [depth (_array/vector _uint VIDEO-MAX-COMPONENTS)]
                                    [pixel-stride (_array/vector _int VIDEO-MAX-COMPONENTS)]
                                    [n-planes _uint]
                                    [plane (_array/vector _uint VIDEO-MAX-COMPONENTS)]
                                    [poffset (_array/vector _uint VIDEO-MAX-COMPONENTS)]
                                    [unpack-format (_gi-enum gst-video-format)]))

(define-cstruct _video-info ([finfo _video-format-info-pointer]
                             [interlace-mode (_gi-enum gst-video-interlace-mode)]
                             [flags (_gi-enum gst-video-flags)]
                             [width _int]
                             [height _int]
                             [size _size]
                             [views _int]
                             [chroma-site (_gi-enum gst-video-chroma-site)]
                             [colorimetry _colorimetry]
                             [par-n _int]
                             [par-d _int]
                             [fps-n _int]
                             [fps-d _int]
                             [offset (_array/vector _size VIDEO-MAX-PLANES)]
                             [stride (_array/vector _size VIDEO-MAX-PLANES)]))

(define-cstruct _video-frame ([info _video-info]
                              [flags (_gi-enum gst-video-frame-flags)]
                              [buffer (_gi-struct gst-buffer)]
                              [meta _pointer]
                              [id _int]
                              [data (_array _pointer VIDEO-MAX-PLANES)]
                              [mapping (_array _map-info VIDEO-MAX-PLANES)]))

(define-gst-video video-info-free!
  (_fun _video-info-pointer ~> _void)
  #:wrap (deallocator)
  #:c-id gst_video_info_free)

(define-gst-video video-info-new
  (_fun ~> _video-info-pointer)
  #:wrap (allocator video-info-free!)
  #:c-id gst_video_info_new)

(define-gst-video caps->video-info
  (_fun [info :  _video-info-pointer = (video-info-new)]
        (_gi-struct gst-caps)
        ~> [parsed? :  _bool]
        ~> (and parsed?
                info))
  #:c-id gst_video_info_from_caps)

(define-gst-video video-info->caps
  (_fun _video-info-pointer
        ~> (_gi-struct gst-caps))
  #:c-id gst_video_info_to_caps)

(define (video-info-par info)
  (/ (video-info-par-n info)
     (video-info-par-d info)))

(define (video-info-fps info)
  (/ (video-info-fps-n info)
     (video-info-fps-d info)))

(define-gst-video video-frame-map
  (_fun [frame : (_ptr o _video-frame)]
        _video-info-pointer
        (_gi-struct gst-buffer)
        (_gi-enum gst-map-flags)
        ~> [success? : _bool]
        ~> (and success?
                frame))
  #:c-id gst_video_frame_map)

(define-gst-video video-frame-unmap!
  (_fun _video-frame-pointer ~> _void)
  #:c-id gst_video_frame_unmap)

(define (video-frame-planes frame)
  (let* ([data (video-frame-data frame)]
         [info (video-frame-info frame)]
         [finfo (video-info-finfo info)]
         [poffset (video-format-info-poffset finfo )])
    (for/vector ([p (in-range (video-format-info-n-planes finfo))])
      (let ([offset (vector-ref poffset p)])
        (array-ref data offset)))))

(define (video-frame-plane-data frame plane)
  (array-ref (video-frame-data frame) plane))

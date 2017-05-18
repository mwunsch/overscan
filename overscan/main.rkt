#lang racket/base

(require gstreamer
         ffi/unsafe
         ffi/unsafe/introspection)

(provide camera
         screen
         audio)

(let-values ([(initialized? argc argv) ((gst 'init_check) 0 #f)])
  (if initialized?
      (displayln ((gst 'version_string)))
      (error "Could not load Gstreamer")))

(define audio-devices
  (let ([monitor ((gst 'DeviceMonitor) 'new)])
    (if (< (send monitor add-filter "Audio/Source" #f) 0)
        (displayln "No Audio Devices detected.")
        (for/vector ([device (send monitor get-devices)]
                     [i (in-naturals)])
          (displayln (format "Audio Device ~a: ~a" i (send device get-display-name)))
          device))))

(define (audio ref)
  (let ([device (vector-ref audio-devices ref)])
    (send device create-element (format "osxaudiosrc:~a" ref))))

(define cameras
  (let ([avfvideosrc (element-factory% 'find "avfvideosrc")])
    (list->vector
     (let loop ([ref 0])
       (let* ([name (format "avfvideosrc:camera:~v" ref)]
              [el (send avfvideosrc create #f)])
         (gobject-set! el "device-index" ref _int)
         (if (eq? 'failure (send el set-state 'ready))
             null
             (and (send el set-state 'null)
                  (displayln (format "Camera ~a: ~a" ref name))
                  (cons (lambda (name)
                          (let ([el (send avfvideosrc create name)])
                            (gobject-set! el "device-index" ref _int)
                            el))
                        (loop (add1 ref))))))))))

(define (camera ref)
  (let ([device (vector-ref cameras ref)])
    (device (format "avfvideosrc:camera:~v" ref))))

(define screens
  (let ([avfvideosrc (element-factory% 'find "avfvideosrc")])
    (list->vector
     (let loop ([ref 0])
       (let* ([name (format "avfvideosrc:screen:~v" ref)]
              [el (send avfvideosrc create #f)])
         (gobject-set! el "capture-screen" #t _bool)
         (gobject-set! el "device-index" ref _int)
         (if (eq? 'failure (send el set-state 'ready))
             null
             (and (send el set-state 'null)
                  (displayln (format "Screen Capture ~a: ~a" ref name))
                  (cons (lambda (name)
                          (let ([el (send avfvideosrc create name)])
                            (gobject-set! el "capture-screen" #t _bool)
                            (gobject-set! el "device-index" ref _int)
                            el))
                        (loop (add1 ref))))))))))

(define (screen ref)
  (let ([device (vector-ref screens ref)])
    (device (format "avfvideosrc:screen:~v" ref))))

(define current-broadcast (box #f))

(define video-preview (element-factory% 'make "osxvideosink" "sink:preview"))

(define false-preview (element-factory% 'make "fakesink" "sink:fakepreview"))

(define filter-video (caps% 'from_string "video/x-raw,width=1280,height=720")) ; 720p

(define h264-encoder
  (let ([encoder  (element-factory% 'make "vtenc_h264" "encode:h264")])
    (gobject-set! encoder "bitrate" 3500 _uint)
    (gobject-set! encoder "max-keyframe-interval-duration" (seconds 2) _int64) ; 2 second keyframe interval
    encoder))

(define aac-encoder
  (element-factory% 'make "faac" "encode:aac"))

(define flvmuxer
  (let ([muxer (element-factory% 'make "flvmux" "mux:flv")])
    (gobject-set! muxer "streamable" #t _bool)
    muxer))

(define false-recording (element-factory% 'make "fakesink" "sink:fakerecording"))

(define debug:fps
  (let ([debug (element-factory% 'make "fpsdisplaysink" "debug:fps")])
    (gobject-set! debug "video-sink" video-preview (_gi-object element%))
    debug))

(define (broadcast scene
                   #:preview [preview debug:fps]
                   #:record [record #f])
  (let ([pipeline (pipeline% 'new "broadcast")]
        [tee (element-factory% 'make "tee" #f)]
        [queue (element-factory% 'make "queue" #f)]
        [record-sink (if record
                         (recording record)
                         false-recording)]
        [preview (or preview
                     false-preview)])
    (or (and (bin-add-many pipeline scene tee queue preview h264-encoder aac-encoder flvmuxer record-sink)
             (send scene link-filtered tee filter-video)
             (element-link-many tee queue preview)
             (element-link-many tee h264-encoder flvmuxer)
             (element-link-many scene aac-encoder flvmuxer)
             (send flvmuxer link record-sink)
             (send pipeline set-state 'playing)
             (set-box! current-broadcast pipeline))
        (error "Couldn't start broadcast"))))

(define (stop [broadcast (unbox current-broadcast)])
  (and (or broadcast
           (error "there is no current broadcast"))
       (send broadcast send-event (event% 'new_eos))
       (send broadcast set-state 'null)
       (set-box! current-broadcast #f)))

(define (graphviz [broadcast (unbox current-broadcast)])
  ((gst 'debug_bin_to_dot_data) broadcast 'all))

(define (scene videosrc audiosrc)
  (let ([bin (bin% 'new #f)])
    (or (and (bin-add-many bin videosrc audiosrc)
             (let* ([video-pad (send videosrc get-static-pad "src")]
                    [ghost ((gst 'GhostPad) 'new "video" video-pad)])
               (send bin add-pad ghost))
             (let* ([audio-pad (send audiosrc get-static-pad "src")]
                    [ghost ((gst 'GhostPad) 'new "audio" audio-pad)])
               (send bin add-pad ghost))
             bin)
        (error "could not create scene"))))

(define (recording location)
  (let ([bin (bin% 'new "recording")]
        [filesink (element-factory% 'make "filesink" #f)])
    (gobject-set! filesink "location" location _path)
    (or (and (send bin add filesink)
             (let ([pad (send filesink get-static-pad "sink")])
               (or (and pad
                        (send bin add-pad ((gst 'GhostPad) 'new "sink" pad))
                        bin)
                   (error "could not get sink-pad for recording"))))
        (error "could not make a recording"))))

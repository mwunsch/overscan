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

(define video-720p (caps% 'from_string "video/x-raw,width=1280,height=720,framerate=30/1"))

(define video-480p (caps% 'from_string "video/x-raw,width=854,height=480"))

(define (debug:preview [scale video-480p])
  (let* ([bin (bin% 'new "sink:preview")]
         [scaler (element-factory% 'make "videoscale" "scale:video")]
         [preview (element-factory% 'make "osxvideosink" "sink:preview")]
         [sink-pad (send scaler get-static-pad "sink")])
    (and (bin-add-many bin scaler preview)
         (send scaler link-filtered preview scale)
         (send bin add-pad (ghost-pad% 'new "sink" sink-pad))
         bin)))

(define (debug:fps)
  (let ([debug (element-factory% 'make "fpsdisplaysink" "debug:fps")]
        [video-preview (debug:preview)])
    (gobject-set! debug "video-sink" video-preview (_gi-object element%))
    debug))

(define (broadcast [scenes (list (scene:bars+tone))]
                   #:preview [preview (debug:fps)]
                   #:record [record #f])
  (when (unbox current-broadcast)
    (error "already a broadcast in progress"))
  (let ([pipeline (pipeline% 'new "broadcast")]
        [video-selector (let ([selector (element-factory% 'make "input-selector" "selector:video")])
                          (gobject-set! selector "sync-mode" 'clock _input-selector-sync-mode)
                          (gobject-set! selector "cache-buffers" #t _bool)
                          selector)]
        [audio-selector (let ([selector (element-factory% 'make "input-selector" "selector:audio")])
                          (gobject-set! selector "sync-mode" 'clock _input-selector-sync-mode)
                          (gobject-set! selector "cache-buffers" #t _bool)
                          selector)]
        [tee (element-factory% 'make "tee" #f)]
        [queue (element-factory% 'make "queue" #f)]
        [h264-encoder (let ([encoder  (element-factory% 'make "vtenc_h264" "encode:h264")])
                        (gobject-set! encoder "bitrate" 3500 _uint)
                        (gobject-set! encoder "max-keyframe-interval-duration" (seconds 2) _int64) ; 2 second keyframe interval
                        encoder)]
        [flvmuxer (let ([muxer (element-factory% 'make "flvmux" "mux:flv")])
                    (gobject-set! muxer "streamable" #t _bool)
                    muxer)]
        [aac-encoder (element-factory% 'make "faac" "encode:aac")]
        [record-sink (if record
                         (recording record)
                         (element-factory% 'make "fakesink" "sink:fake-recording"))]
        [preview (or preview
                     (element-factory% 'make "fakesink" "sink:fake-preview"))])
    (or (and (bin-add-many pipeline video-selector tee queue preview h264-encoder audio-selector aac-encoder flvmuxer record-sink)
             (for/and ([scene scenes])
               (and (send pipeline add scene)
                    (send scene link-pads "video" video-selector #f)
                    (send scene link-pads "audio" audio-selector #f)))
             (send video-selector link-filtered tee video-720p)
             (element-link-many tee queue preview)
             (element-link-many tee h264-encoder flvmuxer)
             (element-link-many audio-selector aac-encoder flvmuxer)
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

(define (scene videosrc audiosrc [broadcast (unbox current-broadcast)])
  (let* ([bin (bin% 'new #f)]
         [bin-name (send bin get-name)]
         [videosrc (gst-compose (format "~a:video" bin-name)
                                videosrc
                                (element-factory% 'make "queue" #f)
                                (element-factory% 'make "videorate" #f)
                                (element-factory% 'make "videoscale" #f))]
         [audiosrc (gst-compose (format "~a:audio" bin-name)
                                audiosrc
                                (element-factory% 'make "queue" #f)
                                (element-factory% 'make "audiorate" #f))])
    (or (and (bin-add-many bin videosrc audiosrc)
             (let* ([video-pad (send videosrc get-static-pad "src")]
                    [ghost (ghost-pad% 'new "video" video-pad)])
               (send bin add-pad ghost))
             (let* ([audio-pad (send audiosrc get-static-pad "src")]
                    [ghost (ghost-pad% 'new "audio" audio-pad)])
               (send bin add-pad ghost))
             (if broadcast
                 (add-scene bin broadcast)
                 #t)
             bin)
        (error "could not create scene"))))

(define (add-scene bin [broadcast (unbox current-broadcast)])
  (unless broadcast
    (error "there is no current broadcast!"))
  (let ([video-selector (send broadcast get-by-name "selector:video")]
        [audio-selector (send broadcast get-by-name "selector:audio")])
    (and (not (send broadcast get-by-name (send bin get-name)))
         (send broadcast add bin)
         video-selector
         (send bin link-pads "video" video-selector #f)
         audio-selector
         (send bin link-pads "audio" audio-selector #f)
         bin)))

(define (scene:bars+tone)
  (scene (element-factory% 'make "videotestsrc" #f)
         (element-factory% 'make "audiotestsrc" #f)))

(define (scene:camera+mic)
  (scene (camera 0) (audio 0)))

(define (scene:screen+mic)
  (scene (screen 0) (audio 0)))

(define (switch scene-or-id [broadcast (unbox current-broadcast)])
  (unless broadcast
    (error "there is no current broadcast"))
  (define scene-name (if (string? scene-or-id)
                         scene-or-id
                         (send scene-or-id get-name)))
  (cond
    [(send broadcast get-by-name scene-name) =>
     (lambda (scene)
       (let* ([video-pad (send scene get-static-pad "video")]
              [audio-pad (send scene get-static-pad "audio")]
              [video-selector (send broadcast get-by-name "selector:video")]
              [audio-selector (send broadcast get-by-name "selector:audio")]
              [active-video (gobject-get video-selector "active-pad" (_gi-object pad%))]
              [old-video (send active-video get-parent-element)]
              [active-audio (gobject-get audio-selector "active-pad" (_gi-object pad%))]
              [old-audio (send active-audio get-parent-element)]
              [video-peer-pad (send video-pad get-peer)]
              [audio-peer-pad (send audio-pad get-peer)]
              [state-status (send scene set-state 'playing)])
         (and (gobject-set! video-selector "active-pad" video-peer-pad (_gi-object pad%))
              (gobject-set! audio-selector "active-pad" audio-peer-pad (_gi-object pad%))
              state-status)))]
    [else (error (format "scene ~a is not part of the broadcast" scene-name))]))

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
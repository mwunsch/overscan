#lang racket/base

(require gstreamer
         ffi/unsafe
         ffi/unsafe/introspection)

(provide camera
         screen
         audio
         broadcast
         stop
         scene
         switch
         scene:camera+mic
         scene:bars+tone)

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
    (element-factory% 'make "osxaudiosrc" (format "osxaudiosrc:~a" ref))
    ;; (send device create-element (format "osxaudiosrc:~a" ref))
    ;; When we use the above method, the returned elements aren't properly
    ;; deallocated
    ))

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

(define (stream:twitch #:test [bandwidth-test #t])
  (let* ([stream-key (getenv "TWITCH_STREAM_KEY")]
         [rtmp (element-factory% 'make "rtmpsink" "sink:rtmp:twitch")]
         [location (format "rtmp://live-jfk.twitch.tv/app/~a~a live=1"
                           stream-key
                           (if bandwidth-test "?bandwidthtest=true" ""))])
    (unless stream-key
      (error "no TWITCH_STREAM_KEY in env"))
    (gobject-set! rtmp "location" location _string)
    rtmp))

(define (stream:fake)
  (element-factory% 'make "fakesink" "sink:rtmp:fake"))

(define current-broadcast (box #f))

(define video-720p (caps% 'from_string "video/x-raw,width=1280,height=720"))

(define video-480p (caps% 'from_string "video/x-raw,width=854,height=480"))

(define (debug:preview [scale video-480p])
  (let* ([bin (bin% 'new "debug:preview")]
         [scaler (element-factory% 'make "videoscale" "debug:preview:scale")]
         [preview (element-factory% 'make "osxvideosink" "debug:preview:sink")]
         [sink-pad (send scaler get-static-pad "sink")])
    (and (bin-add-many bin scaler preview)
         (send scaler link-filtered preview scale)
         (send bin add-pad (ghost-pad% 'new "sink" sink-pad))
         bin)))

(define (debug:fps [video-preview (debug:preview)])
  (let ([debug (element-factory% 'make "fpsdisplaysink" "debug:fps")])
    (gobject-set! debug "video-sink" video-preview (_gi-object element%))
    debug))

(define (debug:audio-monitor)
  (element-factory% 'make "osxaudiosink" "debug:monitor"))

(define (broadcast [scenes (list (scene:bars+tone))]
                   [rtmpsink (stream:fake)]
                   #:preview [preview (debug:fps)]
                   #:record [record #f]
                   #:monitor [monitor #f])
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
        [video-tee (element-factory% 'make "tee" "tee:video")]
        [video-queue (element-factory% 'make "queue" "buffer:video")]
        [audio-tee (element-factory% 'make "tee" "tee:audio")]
        [audio-queue (element-factory% 'make "queue" "buffer:audio")]
        [h264-encoder (let ([encoder (element-factory% 'make "x264enc" "encode:h264")])
                        (gobject-set! encoder "bitrate" 1500 _uint)
                        (gobject-set! encoder "key-int-max" 2 _int)
                        (gobject-set! encoder "speed-preset" 4 _int)
                        (gobject-set! encoder "rc-lookahead" 5 _int)
                        encoder)]
        [aac-encoder (element-factory% 'make "faac" "encode:aac")]
        [flvmuxer (let ([muxer (element-factory% 'make "flvmux" "mux:flv")])
                    (gobject-set! muxer "streamable" #t _bool)
                    muxer)]
        [flvtee (element-factory% 'make "tee" "tee:flv")]
        [rtmpqueue (element-factory% 'make "queue" "buffer:rtmp")]
        [preview-queue (let ([buffer (element-factory% 'make "queue" "buffer:preview")])
                        (gobject-set! buffer "leaky" 'upstream (_enum '(no upstream downstream)))
                        buffer)]
        [preview (gst-compose "sink:preview"
                              (element-factory% 'make "videoconvert" #f)
                              (or preview
                                  (element-factory% 'make "fakesink" "sink:preview:fake")))]
        [recording-queue (element-factory% 'make "queue" "buffer:recording")]
        [record-sink (or (recording record)
                         (element-factory% 'make "fakesink" "sink:recording:fake"))]
        [monitor-queue (let ([buffer (element-factory% 'make "queue" "buffer:monitor")])
                        (gobject-set! buffer "leaky" 'upstream (_enum '(no upstream downstream)))
                        buffer)]
        [audio-monitor (or monitor
                           (element-factory% 'make "fakesink" "sink:monitor:fake"))])
    (or (and (bin-add-many pipeline
                           video-selector video-tee preview-queue preview
                           audio-selector audio-tee monitor-queue audio-monitor
                           video-queue h264-encoder audio-queue aac-encoder
                           flvmuxer flvtee rtmpqueue rtmpsink)
             (for/and ([scene scenes])
               (and (send pipeline add scene)
                    (send scene link-pads "video" video-selector #f)
                    (send scene link-pads "audio" audio-selector #f)))

             (send video-selector link video-tee)
             (send audio-selector link audio-tee)

             (send video-tee link-filtered video-queue video-720p)
             (send audio-tee link audio-queue)

             (send video-tee link preview-queue)
             (send preview-queue link preview)

             (send audio-tee link monitor-queue)
             (send monitor-queue link audio-monitor)

             (send video-queue link h264-encoder)
             (send audio-queue link aac-encoder)

             (send h264-encoder link flvmuxer)
             (send aac-encoder link flvmuxer)
             (send flvmuxer link flvtee)

             (send flvtee link rtmpqueue)
             (send rtmpqueue link rtmpsink)

             (if record
                 (and (bin-add-many pipeline recording-queue record-sink)
                      (send flvtee link recording-queue)
                      (send recording-queue link record-sink))
                 #t)

             (send pipeline set-state 'playing)
             (set-box! current-broadcast pipeline))
        (error "Couldn't start broadcast"))))

(define (stop [broadcast (unbox current-broadcast)])
  (and (or broadcast
           (error "there is no current broadcast"))
       (send broadcast send-event (event% 'new_eos))
       (send broadcast set-state 'null)
       (set-box! current-broadcast #f)))

(define (graphviz filepath [broadcast (unbox current-broadcast)])
  (call-with-output-file filepath
    (lambda (out)
      (display ((gst 'debug_bin_to_dot_data) broadcast 'all) out))))

(define (scene videosrc audiosrc [broadcast (unbox current-broadcast)])
  (let* ([bin (bin% 'new #f)]
         [bin-name (send bin get-name)])
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
         (send bin set-state 'playing))))

(define (scene:bars+tone)
  (let ([elements (list (element-factory% 'make "videotestsrc" #f)
                        (element-factory% 'make "audiotestsrc" #f))])
    (apply scene
           (map (lambda (el) (and (gobject-set! el "is-live" #t _bool) el)) elements))))

(define (scene:snow)
  (scene (let ([video (element-factory% 'make "videotestsrc" #f)])
           (gobject-set! video "is-live" #t _bool)
           (gobject-set! video "pattern" 'snow _video-test-src-pattern)
           video)
         (let ([audio (element-factory% 'make "audiotestsrc" #f)])
           (gobject-set! audio "is-live" #t _bool)
           (gobject-set! audio "wave" 'white-noise _audio-test-src-wave)
           audio)))

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
              [audio-peer-pad (send audio-pad get-peer)])
         (and (gobject-set! video-selector "active-pad" video-peer-pad (_gi-object pad%))
              (gobject-set! audio-selector "active-pad" audio-peer-pad (_gi-object pad%))
              scene)))]
    [else (error (format "scene ~a is not part of the broadcast" scene-name))]))

(define (recording location)
  (let ([bin (bin% 'new "sink:recording")]
        [filesink (element-factory% 'make "filesink" #f)])
    (gobject-set! filesink "location" location _path)
    (or (and (send bin add filesink)
             (let ([pad (send filesink get-static-pad "sink")])
               (or (and pad
                        (send bin add-pad ((gst 'GhostPad) 'new "sink" pad))
                        bin)
                   (error "could not get sink-pad for recording"))))
        (error "could not make a recording"))))

(module+ main
  (define scene0 (scene:camera+mic))
  (define scene1 (scene:bars+tone)))

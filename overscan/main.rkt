#lang racket/base

(require gstreamer
         ffi/unsafe
         ffi/unsafe/introspection
         (only-in racket/function thunk))

(provide camera
         screen
         audio
         broadcast
         stop
         scene
         add-scene
         switch
         scene:camera+mic
         scene:screen+mic
         scene:bars+tone
         scene:snow
         scene:picture-in-picture
         scene:camera+screen
         stream:twitch
         debug:preview
         debug:fps
         debug:audio-monitor
         graphviz)

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
                          (gobject-with-properties (send avfvideosrc create name)
                                                   (hash 'device-index ref)))
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
                          (gobject-with-properties (send avfvideosrc create name)
                                                   (hash 'capture-screen #t
                                                         'device-index ref)))
                        (loop (add1 ref))))))))))

(define (screen ref)
  (let ([device (vector-ref screens ref)])
    (device (format "avfvideosrc:screen:~v" ref))))

(define (stream:twitch #:test [bandwidth-test #f])
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

(define video-720p (caps% 'from_string "video/x-raw,width=1280,height=720,pixel-aspect-ratio=1/1"))

(define video-480p (caps% 'from_string "video/x-raw,width=854,height=480,pixel-aspect-ratio=1/1"))

(define video-360p (caps% 'from_string "video/x-raw,width=480,height=360,pixel-aspect-ratio=1/1"))

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

(define (debug:audio-monitor [volume 0.5])
  (let ([sink (element-factory% 'make "osxaudiosink" "debug:monitor")])
    (gobject-set! sink "volume" volume _double)
    sink))

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
        [h264-encoder (let ([encoder (element-factory% 'make "vtenc_h264_hw" "encode:h264")])
                        (gobject-set! encoder "bitrate" 2500)
                        (gobject-set! encoder "realtime" #t)
                        (gobject-set! encoder "max-keyframe-interval-duration" (seconds 2) _uint64)
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
        [preview (and preview
                      (gst-compose "sink:preview"
                                   (element-factory% 'make "videoconvert" #f)
                                   preview))]
        [recording-queue (element-factory% 'make "queue" "buffer:recording")]
        [record-sink (or (recording record)
                         (element-factory% 'make "fakesink" "sink:recording:fake"))]
        [monitor-queue (let ([buffer (element-factory% 'make "queue" "buffer:monitor")])
                         (gobject-set! buffer "leaky" 'upstream (_enum '(no upstream downstream)))
                         buffer)]
        [audio-monitor (or monitor
                           (element-factory% 'make "fakesink" "sink:monitor:fake"))])
    (or (and (bin-add-many pipeline
                           video-selector video-tee video-queue h264-encoder
                           audio-selector audio-tee audio-queue aac-encoder
                           flvmuxer flvtee rtmpqueue rtmpsink)
             (for/and ([scene (map scene-bin scenes)])
               (and (send pipeline add scene)
                    (send scene link-pads "video" video-selector #f)
                    (send scene link-pads "audio" audio-selector #f)))

             (send video-selector link video-tee)
             (send audio-selector link audio-tee)

             (send video-tee link-filtered video-queue video-720p)
             (send audio-tee link audio-queue)

             (if preview
                 (and (bin-add-many pipeline preview-queue preview)
                      (send video-tee link preview-queue)
                      (send preview-queue link preview))
                 #t)

             (if monitor
                 (and (bin-add-many pipeline monitor-queue audio-monitor)
                      (send audio-tee link monitor-queue)
                      (send monitor-queue link audio-monitor))
                 #t)

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
  (unless broadcast
    (error "there is no current broadcast"))
  (send broadcast send-event (event% 'new_eos))
  (send broadcast set-state 'null)
  (set-box! current-broadcast #f))

(define (graphviz filepath [broadcast (unbox current-broadcast)])
  (call-with-output-file filepath
    (lambda (out)
      (display ((gst 'debug_bin_to_dot_data) broadcast 'all) out))))

(struct scene (bin port)
  #:name SCENE
  #:constructor-name make-scene
  #:property prop:output-port 1
  #:property prop:object-name
  (lambda (scene) (scene-name scene)))

(define (scene-name scene)
  (let ([bin (scene-bin scene)])
    (string->symbol (send bin get-name))))

(define (scene videosrc audiosrc [name #f])
  (define bin (bin% 'new name))
  (define bin-name (send bin get-name))
  (define bin-sym (string->symbol bin-name))
  (define-values (input-port output-port) (make-pipe #f bin-sym bin-sym))
  (let* ([instance (make-scene bin output-port)]
         [scaler (element-factory% 'make "videoscale" #f)]
         [text (element-factory% 'make "textoverlay" (format "~a:text" bin-name))]
         [multiqueue (element-factory% 'make "multiqueue" #f)]
         [text-worker (thread (thunk
                               (let loop ()
                                 (or (port-closed? input-port)
                                     (let ([line (read-line input-port)])
                                       (gobject-set! text "text" line)
                                       (loop))))))])
    (or (and (bin-add-many bin videosrc text scaler audiosrc multiqueue)
             (gobject-set! multiqueue "max-size-time" (seconds 2) _uint64)
             (send videosrc link-filtered text (caps% 'from_string "video/x-raw,pixel-aspect-ratio=1/1"))
             (send text link scaler)
             (send scaler link multiqueue)
             (send audiosrc link multiqueue)
             (let* ([video-pad (send multiqueue get-static-pad "src_0")]
                    [ghost (ghost-pad% 'new "video" video-pad)])
               (send bin add-pad ghost))
             (let* ([audio-pad (send multiqueue get-static-pad "src_1")]
                    [ghost (ghost-pad% 'new "audio" audio-pad)])
               (send bin add-pad ghost))
             instance)
        (error "could not create scene"))))

(define (add-scene scene [broadcast (unbox current-broadcast)])
  (define bin (scene-bin scene))
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

(define (scene:picture-in-picture video1 video2 audio)
  (let* ([bin (bin% 'new #f)]
         [bin-name (send bin get-name)]
         [mixer (element-factory% 'make "videomixer" (format "~a:mixer" bin-name))]
         [videobox (gst-compose "pip:box"
                                (element-factory% 'make "videoscale" #f)
                                (let ([caps (element-factory% 'make "capsfilter" #f)])
                                  (gobject-set! caps "caps" video-360p _pointer)
                                  caps)
                                (element-factory% 'make "videobox" #f))])
    (or (and (bin-add-many bin video1 videobox video2 mixer audio)
             (send video2 link-filtered mixer (caps% 'from_string "video/x-raw,width=1280,height=720,framerate=30/1,pixel-aspect-ratio=1/1"))
             (send video1 link videobox)
             (send videobox link mixer)
             (let ([pad (send mixer get-static-pad "sink_1")])
               (gobject-set! pad "ypos" 320 _int)
               (gobject-set! pad "xpos" 20 _int))
             (let* ([video-pad (send mixer get-static-pad "src")]
                    [ghost (ghost-pad% 'new "video" video-pad)])
               (send bin add-pad ghost))
             (let* ([audio-pad (send audio get-static-pad "src")]
                    [ghost (ghost-pad% 'new "audio" audio-pad)])
               (send bin add-pad ghost))
             bin)
        (error "could not create mix"))))

(define (scene:camera+screen [camref 0] [scrnref 0])
  (scene:picture-in-picture (camera camref)
                            (gst-compose "pip:screen"
                                         (screen scrnref)
                                         (element-factory% 'make "videoscale" #f))
                            (audio 0)))

(define (switch scene-or-id [broadcast (unbox current-broadcast)])
  (unless broadcast
    (error "there is no current broadcast"))
  (define bin-name (if (string? scene-or-id)
                         scene-or-id
                         (symbol->string (scene-name scene-or-id))))
  (cond
    [(send broadcast get-by-name bin-name) =>
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
    [else (error (format "scene ~a is not part of the broadcast" bin-name))]))

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
  ;; Let's make a stream!

  ;; First, I define the "scenes", which are video/audio pairs
  (define cam+mic (scene:camera+mic))
  (define screen+mic (scene:screen+mic))
  (define bars+tone (scene:bars+tone))
  (define pip (scene:camera+screen 0 0))


  ;; Then, I create the broadcast with the scenes:
  ;; (broadcast (list cam+mic screen+mic bars+tone) (stream:twitch #:test #t)
  ;;            #:record "testing-05-25-2017.flv")

  ;; Danger: Picture-in-Picture is really volatile and flaky
  ; (add-scene pip)
  ; (switch pip)

  ;; Switch scenes with switch:
  ; (switch bars+tone)

  ;; End the stream with stop:
  ; (stop)
  )

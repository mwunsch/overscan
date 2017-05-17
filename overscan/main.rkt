#lang racket/base

(require gstreamer
         ffi/unsafe
         ffi/unsafe/introspection)

(let-values ([(initialized? argc argv) ((gst 'init_check) 0 #f)])
  (if initialized?
      (displayln ((gst 'version_string)))
      (error "Could not load Gstreamer")))

(define current-broadcast (box #f))

(define video-preview (element-factory% 'make "osxvideosink" "sink:preview"))

(define false-preview (element-factory% 'make "fakesink" "sink:fakepreview"))

(define filter-video (caps% 'from_string "video/x-raw"))

(define h264-encoder (element-factory% 'make "vtenc_h264" "encode:h264"))

(define aac-encoder (element-factory% 'make "faac" "encode:aac"))

(define flvmuxer
  (let ([muxer (element-factory% 'make "flvmux" "mux:flv")])
    (gobject-set! muxer "streamable" #t _bool)
    muxer))

(define false-recording (element-factory% 'make "fakesink" "sink:fakerecording"))

(define (broadcast scene
                   #:preview [preview video-preview]
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
             (element-link-many tee queue:preview preview)
             (element-link-many tee h264-encoder flvmuxer)
             (element-link-many scene aac-encoder flvmuxer)
             (send flvmuxer link record-sink)
             (send pipeline set-state 'playing)
             (set-box! current-broadcast pipeline))
        (error "Couldn't start broadcast"))))

(define (end-broadcast [broadcast (unbox current-broadcast)])
  (and (or broadcast
           (error "there is no current broadcast"))
       (send broadcast send-event (event% 'new_eos))
       (send broadcast set-state 'null)
       (set-box! current-broadcast #f)))

(define (scene . sources)
  (let ([bin (bin% 'new "scene")]
        [camera (element-factory% 'make "avfvideosrc" "camera")]
        [audio (element-factory% 'make "osxaudiosrc" "microphone")])
    (if (bin-add-many bin camera audio)
        (let* ([camera-pad (send camera get-static-pad "src")]
               [audio-pad (send audio get-static-pad "src")])
          (or (and camera-pad
                   (send bin add-pad ((gst 'GhostPad) 'new "video" camera-pad))
                   audio-pad
                   (send bin add-pad ((gst 'GhostPad) 'new "audio" audio-pad))
                   bin)
              (error "could not create scene")))
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

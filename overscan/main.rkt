#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function thunk)
         gstreamer
         overscan/twitch)

(provide (contract-out [current-broadcast
                        (box/c (or/c (is-a?/c pipeline%) false/c))]
                       [broadcast
                        (->* ()
                             (source? sink?)
                             evt?)]
                       [stop
                        (-> void?)])
         (all-from-out racket/base
                       gstreamer
                       overscan/twitch))


(unless (gst-initialized?)
  (if (gst-initialize)
      (displayln (gst-version-string))
      (error "Could not load GStreamer")))

(define current-broadcast
  (box #f))

(define current-bus
  (box #f))

(define (default-broadcast-listener msg broadcast)
  (when (eos-or-error-message? msg)
    (send broadcast set-state 'null)))

(define broadcast-listeners
  (make-hash (list (cons 0 default-broadcast-listener))))

(define (make-fake-source)
  (element-factory%-make "fakesrc" "source:fake"))

(define (make-fake-sink)
  (element-factory%-make "fakesink" "sink:fake"))

(define (broadcast [source (make-fake-source)]
                   [sink (make-fake-sink)])
  (when (unbox current-broadcast)
    (error "Already a broadcast in progress"))
  (let* ([pipeline (pipeline%-new #f)])
    (and (send pipeline add source)
         (send pipeline add sink)
         (send source link sink)
         (set-box! current-broadcast pipeline)
         (set-box! current-bus (spawn-bus-worker pipeline))
         (send pipeline set-state 'playing))))

(define (stop)
  (define broadcast (get-current-broadcast))
  (define bus (unbox current-bus))
  (send broadcast send-event (make-eos-event))
  (thread-wait bus)
  (let-values ([(result current pending) (send broadcast get-state)])
    (set-box! current-broadcast #f)
    (set-box! current-bus #f)
    result))

(define (spawn-bus-worker broadcast)
  (let* ([bus (send broadcast get-bus)]
         [chan (make-bus-channel bus)])
    (thread (thunk
             (let loop ()
                  (let ([ev (sync chan)])
                    (unless (evt? ev)
                      (for ([proc (in-hash-values broadcast-listeners)])
                           (proc ev broadcast))
                      (loop))))))))

(define (add-listener proc)
  (let* ([stack broadcast-listeners]
         [key (hash-count stack)])
    (hash-set! stack key proc)
    key))

(define (remove-listener key)
  (hash-remove! broadcast-listeners key))

(define (eos-or-error-message? msg)
  (and (message? msg)
       (memf (symbols 'eos 'error) (message-type msg))))

(define (playing? [broadcast (get-current-broadcast)])
  (let-values ([(result current pending) (send broadcast get-state)])
    (and (eq? result 'success)
         (eq? current 'playing))))

(define (graphviz filepath [broadcast (get-current-broadcast)])
  (call-with-output-file filepath
    (lambda (out)
      (display (bin->dot broadcast) out))))

(define (get-current-broadcast)
  (or (unbox current-broadcast)
      (error "No current broadcast")))

(module reader syntax/module-reader
  overscan)

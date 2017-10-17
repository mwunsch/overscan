#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         gstreamer/gst)

(provide (contract-out [caps?
                        (-> any/c boolean?)]
                       [string->caps
                        (-> string? (or/c caps? false/c))]
                       [caps->string
                        (-> caps? string?)]
                       [caps-append!
                        (-> caps? caps? void?)]
                       [caps-any?
                        (-> caps? boolean?)]
                       [caps-empty?
                        (-> caps? boolean?)]
                       [caps-fixed?
                        (-> caps? boolean?)]
                       [caps=?
                        (-> caps? caps? boolean?)]))

(define gst-caps (gst 'Caps))

(define (caps? v)
  (is-gtype? v gst-caps))

(define (string->caps str)
  (gst-caps 'from_string str))

(define (caps->string caps)
  (gobject-send caps 'to_string))

(define (caps-append! cap1 cap2)
  (gobject-send cap1 'append cap2))

(define (caps-any? caps)
  (gobject-send caps 'is_any))

(define (caps-empty? caps)
  (gobject-send caps 'is_empty))

(define (caps-fixed? caps)
  (gobject-send caps 'is_fixed))

(define (caps=? caps1 caps2)
  (gobject-send caps1 'is_equal caps2))

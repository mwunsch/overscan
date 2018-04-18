#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         "private/core.rkt"
         "private/structure.rkt")

(provide (contract-out [caps?
                        (-> any/c boolean?)]
                       [string->caps
                        (-> string? (or/c caps? false/c))]
                       [caps->string
                        (-> caps? string?)]
                       [caps-merge!
                        (-> caps? caps? caps?)]
                       [caps-append!
                        (-> caps? caps? void?)]
                       [caps-any?
                        (-> caps? boolean?)]
                       [caps-empty?
                        (-> caps? boolean?)]
                       [caps-fixed?
                        (-> caps? boolean?)]
                       [caps=?
                        (-> caps? caps? boolean?)]
                       [caps-size
                        (-> caps?
                            exact-nonnegative-integer?)]
                       [caps-structure
                        (-> caps?
                            exact-nonnegative-integer?
                            gst-structure?)]))

(define (caps? v)
  (is-gtype? v gst-caps))

(define (string->caps str)
  (gst-caps 'from_string str))

(define (caps->string caps)
  (gobject-send caps 'to_string))

(define (caps-merge! cap1 cap2)
  (gobject-send cap1 'merge cap2))

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

(define (caps-size caps)
  (gobject-send caps 'get_size))

(define (caps-structure caps index)
  (gobject-send caps 'get_structure index))

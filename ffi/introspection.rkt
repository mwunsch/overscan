#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc)

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))

(define _GITypelib (_cpointer 'GITypelib))

(define-gir g_irepository_require (_fun (_pointer = #f) _string _string _int _pointer -> _GITypelib))
(define-gir g_irepository_find_by_name (_fun (_pointer = #f) _string _string -> _pointer))
(define-gir g_irepository_get_n_infos (_fun (_pointer = #f) _string -> _int))

(define (gir-require namespace)
  (g_irepository_require namespace #f 0 #f))

#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define)

(define-ffi-definer define-g-irepository (ffi-lib "libgirepository-1.0"))

(define-g-irepository g_irepository_require (_fun (_pointer = #f) _string _string _int _pointer -> _pointer))

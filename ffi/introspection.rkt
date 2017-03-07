#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc)

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))

(define _gi-base-info (_cpointer 'GIBaseInfo))
(define _gi-info-type (_enum '(invalid
                               function
                               callback
                               struct
                               boxed
                               enum
                               flags
                               object
                               interface
                               constant
                               invalid-0
                               union
                               value
                               signal
                               vfunc
                               property
                               field
                               arg
                               type
                               unresolved)))

(define-gir g_base_info_get_namespace (_fun _gi-base-info -> _string))
(define-gir g_base_info_get_name (_fun _gi-base-info -> _string))
(define-gir g_base_info_get_type (_fun _gi-base-info -> _gi-info-type))
(define-gir g_base_info_unref (_fun _gi-base-info -> _void)
  #:wrap (deallocator))

(define-gir g_irepository_require (_fun (_pointer = #f) _string _string _int _pointer -> _pointer))
(define-gir g_irepository_get_n_infos (_fun (_pointer = #f) _string -> _int))
(define-gir g_irepository_get_info (_fun (_pointer = #f) _string _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))
(define-gir g_irepository_find_by_name (_fun (_pointer = #f) _string _string -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define (gir-require namespace)
  (g_irepository_require namespace #f 0 #f))

(define (introspect namespace)
  (gir-require namespace)
  (for/list ([i (in-range (g_irepository_get_n_infos namespace))])
    (let ([_info (g_irepository_get_info namespace i)])
      (cons (g_base_info_get_type _info) (g_base_info_get_name _info)))))

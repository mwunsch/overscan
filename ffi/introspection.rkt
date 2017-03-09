#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc)

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))

(define-cstruct _gerror ([domain _uint32] [code _int] [message _string]))
(define _gi-type-lib (_cpointer/null 'GITypelib))
(define _gi-base-info (_cpointer/null 'GIBaseInfo))
(define _gi-type-info (_cpointer/null 'GITypeInfo))
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
(define _gi-type-tag (_enum '(void
                              bool
                              int8
                              uint8
                              int16
                              uint16
                              int32
                              uint32
                              int64
                              uint64
                              float
                              double
                              gtype
                              utf8
                              filename
                              array
                              interface
                              glist
                              gslist
                              ghash
                              gerror
                              unichar)))
(define _gi-function-info-flags (_bitmask '(method?
                                            constructor?
                                            getter?
                                            setter?
                                            wraps-vfunc?
                                            throws?)))

(define-gir g_base_info_get_namespace (_fun _gi-base-info -> _string))
(define-gir g_base_info_get_name (_fun _gi-base-info -> _string))
(define-gir g_base_info_get_type (_fun _gi-base-info -> _gi-info-type))
(define-gir g_base_info_unref (_fun _gi-base-info -> _void)
  #:wrap (deallocator))

(define-gir g_irepository_require (_fun (_pointer = #f) _string _string _int (err : (_ptr io _gerror-pointer/null) = #f)
                                        -> (r : _gi-type-lib)
                                        -> (or r
                                               (error (gerror-message err)))))
(define-gir g_irepository_get_n_infos (_fun (_pointer = #f) _string -> _int))
(define-gir g_irepository_get_info (_fun (_pointer = #f) _string _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))
(define-gir g_irepository_find_by_name (_fun (_pointer = #f) _string _string -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_callable_info_get_n_args (_fun _gi-base-info -> _int))
(define-gir g_callable_info_get_return_type (_fun _gi-base-info -> (r : _gi-type-info)
                                                  -> (begin (cpointer-push-tag! r 'GIBaseInfo) r)))

(define-gir g_type_info_get_tag (_fun _gi-type-info -> _gi-type-tag))

(define-gir g_function_info_get_flags (_fun _gi-base-info -> _gi-function-info-flags))

(define (introspection-info namespace)
  (g_irepository_require namespace #f 0)
  (for/list ([i (in-range (g_irepository_get_n_infos namespace))])
    (let ([_info (g_irepository_get_info namespace i)])
      (cons (g_base_info_get_type _info) (g_base_info_get_name _info)))))

(define (introspection namespace)
  (g_irepository_require namespace #f 0)
  (lambda (name)
    (let ([info (or (g_irepository_find_by_name namespace name)
                    (raise-argument-error 'introspection "name in GIR namespace" name))])
      (gi-binding info))))

(define (gi-binding info)
  (let ([info-type (g_base_info_get_type info)])
    (case info-type
      [(function) (let* ([n-args (g_callable_info_get_n_args info)]
                         [return-type (g_callable_info_get_return_type info)]
                         [type-tag (g_type_info_get_tag return-type)])
                    (format "fun ~v -> ~v" n-args type-tag))]
      [else (cons info-type (g_base_info_get_name info))])))

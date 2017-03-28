#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc
         (only-in racket/list index-of partition last filter-map)
         (only-in racket/function curry))

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))

(define-cstruct _gerror ([domain _uint32] [code _int] [message _string]))
(define _gi-base-info (_cpointer/null 'GIBaseInfo))
(define _gi-info-type (_enum '(GI_INFO_TYPE_INVALID
                               GI_INFO_TYPE_FUNCTION
                               GI_INFO_TYPE_CALLBACK
                               GI_INFO_TYPE_STRUCT
                               GI_INFO_TYPE_BOXED
                               GI_INFO_TYPE_ENUM
                               GI_INFO_TYPE_FLAGS
                               GI_INFO_TYPE_OBJECT
                               GI_INFO_TYPE_INTERFACE
                               GI_INFO_TYPE_CONSTANT
                               GI_INFO_TYPE_INVALID_0
                               GI_INFO_TYPE_UNION
                               GI_INFO_TYPE_VALUE
                               GI_INFO_TYPE_SIGNAL
                               GI_INFO_TYPE_VFUNC
                               GI_INFO_TYPE_PROPERTY
                               GI_INFO_TYPE_FIELD
                               GI_INFO_TYPE_ARG
                               GI_INFO_TYPE_TYPE
                               GI_INFO_TYPE_UNRESOLVED)))
(define _gi-type-tag (_enum '(GI_TYPE_TAG_VOID
                              GI_TYPE_TAG_BOOLEAN
                              GI_TYPE_TAG_INT8
                              GI_TYPE_TAG_UINT8
                              GI_TYPE_TAG_INT16
                              GI_TYPE_TAG_UINT16
                              GI_TYPE_TAG_INT32
                              GI_TYPE_TAG_UINT32
                              GI_TYPE_TAG_INT64
                              GI_TYPE_TAG_UINT64
                              GI_TYPE_TAG_FLOAT
                              GI_TYPE_TAG_DOUBLE
                              GI_TYPE_TAG_GTYPE
                              GI_TYPE_TAG_UTF8
                              GI_TYPE_TAG_FILENAME
                              GI_TYPE_TAG_ARRAY
                              GI_TYPE_TAG_INTERFACE
                              GI_TYPE_TAG_GLIST
                              GI_TYPE_TAG_GSLIST
                              GI_TYPE_TAG_GHASH
                              GI_TYPE_TAG_ERROR
                              GI_TYPE_TAG_UNICHAR)))
(define _gi-function-info-flags (_bitmask '(GI_FUNCTION_IS_METHOD
                                            GI_FUNCTION_IS_CONSTRUCTOR
                                            GI_FUNCTION_IS_GETTER
                                            GI_FUNCTION_IS_SETTER
                                            GI_FUNCTION_WRAPS_VFUNC
                                            GI_FUNCTION_THROWS)))
(define gi-argument-type-list (list _bool _int8 _uint8 _int16 _uint16 _int32 _uint32
                                    _int64 _uint64 _float _double
                                    _short _ushort _int _uint _long _ulong _ssize _size
                                    _string _pointer))
(define _gi-argument (apply _union gi-argument-type-list))
(define _gi-direction (_enum '(i o io)))

(define-gir g_base_info_get_namespace (_fun _gi-base-info -> _string))
(define-gir g_base_info_get_name (_fun _gi-base-info -> _string))
(define-gir g_base_info_get_type (_fun _gi-base-info -> _gi-info-type))
(define-gir g_base_info_unref (_fun _gi-base-info -> _void)
  #:wrap (deallocator))

(define-gir g_irepository_require (_fun (_pointer = #f) _string _string _int (err : (_ptr io _gerror-pointer/null) = #f)
                                        -> (r : _pointer)
                                        -> (or r
                                               (error (gerror-message err)))))
(define-gir g_irepository_get_n_infos (_fun (_pointer = #f) _string -> _int))
(define-gir g_irepository_get_info (_fun (_pointer = #f) _string _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))
(define-gir g_irepository_find_by_name (_fun (_pointer = #f) _string _string -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_callable_info_get_n_args (_fun _gi-base-info -> _int))
(define-gir g_callable_info_get_arg (_fun _gi-base-info _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))
(define-gir g_callable_info_can_throw_gerror (_fun _gi-base-info -> _bool))
(define-gir g_callable_info_get_return_type (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_arg_info_get_type (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))
(define-gir g_arg_info_get_direction (_fun _gi-base-info -> _gi-direction))

(define-gir g_type_info_get_tag (_fun _gi-base-info -> _gi-type-tag))
(define-gir g_type_info_is_pointer (_fun _gi-base-info -> _bool))

(define-gir g_function_info_get_flags (_fun _gi-base-info -> _gi-function-info-flags))
(define-gir g_function_info_invoke (_fun _gi-base-info
                                         [inargs : (_list i _gi-argument)] [_int = (length inargs)]
                                         [outargs : (_list i _gi-argument)] [_int = (length outargs)]
                                         [r : (_ptr o _gi-argument)]
                                         (err : (_ptr io _gerror-pointer/null) = #f)
                                         -> (invoked : _bool)
                                         -> (if invoked r (error (gerror-message err)))))

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
  (let ([info-type (g_base_info_get_type info)]
        [info-name (string->symbol (g_base_info_get_name info))])
    (case info-type
      ['GI_INFO_TYPE_FUNCTION (gir/function info)]
      [else (cons info-type info-name)])))

(struct gir/function (info)
  #:property
  prop:procedure
  (lambda (f . arguments)
    (let* ([funinfo (gir/function-info f)]
           [n_args (g_callable_info_get_n_args funinfo)])
      (when (not (eqv? (length arguments) n_args))
        (apply raise-arity-error f n_args arguments))
      (define arginfos (build-list n_args (curry g_callable_info_get_arg funinfo)))
      (define return-type (type-info->ctype
                           (g_callable_info_get_return_type funinfo)))
      (define args (map make-argument arginfos arguments))
      (define-values (args-in args-out)
        (values (map argument-value (filter (argument-direction? '(i io)) args))
                (map argument-value (filter (argument-direction? '(o io)) args))))
      (let ([invocation (g_function_info_invoke funinfo args-in args-out)])
        (gi-arg->value-of-type invocation return-type)))))

(struct argument (value type direction))

(define (make-argument arginfo value)
  (define arg-ctype ((compose1 type-info->ctype g_arg_info_get_type) arginfo))
  (argument ((ctype->value->gi-argument arg-ctype) value)
            arg-ctype
            (g_arg_info_get_direction arginfo)))

(define (argument-direction? dir)
  (lambda (argument)
    (memq (argument-direction argument) dir)))

(define (type-info->ctype info)
  (let ([type-tag (g_type_info_get_tag info)])
    (case type-tag
      ['GI_TYPE_TAG_VOID _void]
      ['GI_TYPE_TAG_BOOLEAN _bool]
      ['GI_TYPE_TAG_INT8 _int8]
      ['GI_TYPE_TAG_UINT8 _uint8]
      ['GI_TYPE_TAG_INT16 _int16]
      ['GI_TYPE_TAG_UINT16 _uint16]
      ['GI_TYPE_TAG_INT32 _int32]
      ['GI_TYPE_TAG_UINT32 _uint32]
      ['GI_TYPE_TAG_INT64 _int64]
      ['GI_TYPE_TAG_UINT64 _uint64]
      ['GI_TYPE_TAG_FLOAT _float]
      ['GI_TYPE_TAG_DOUBLE _double]
      [(GI_TYPE_TAG_UTF8 GI_TYPE_TAG_FILENAME) _string]
      ;; ['GI_TYPE_TAG_GTYPE ]
      ;; ['GI_TYPE_TAG_ARRAY]
      ;; ['GI_TYPE_TAG_INTERFACE]
      ;; ['GI_TYPE_TAG_GLIST]
      ;; ['GI_TYPE_TAG_GSLIST]
      ;; ['GI_TYPE_TAG_GHASH]
      ['GI_TYPE_TAG_ERROR _gerror-pointer]
      ;; ['GI_TYPE_TAG_UNICHAR]
      [else _pointer])))

(define (ctype->value->gi-argument ctype)
  (let* ([giarg-ptr (malloc _gi-argument)]
         [union-val (ptr-ref giarg-ptr _gi-argument)]
         [index (or (index-of gi-argument-type-list ctype)
                    (sub1 (length gi-argument-type-list)))])
    (lambda (value)
      (union-set! union-val index value)
      union-val)))

(define (gi-arg->value-of-type giarg ctype)
  (let ([value (union-ref giarg (or (index-of gi-argument-type-list ctype)
                                    (sub1 (length gi-argument-type-list))))])
    (if (eq? ctype _void) (void value) value)))

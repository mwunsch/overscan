#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc
         (only-in racket/list index-of partition last)
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
  (let ([info-type (g_base_info_get_type info)])
    (case info-type
      ['GI_INFO_TYPE_FUNCTION (gi-bind-function-type info)]
      [else (cons info-type (g_base_info_get_name info))])))

(define (gi-bind-function-type info)
  (define args (callable-arguments info))
  (define return-info (g_callable_info_get_return_type info))
  (define return-type (type-info->ctype return-info))
  (define arguments->gi-arguments
    (map (compose1 ctype->value->gi-argument
                   type-info->ctype
                   g_arg_info_get_type) (filter (arg-direction? '(i io)) args)))
  (lambda arguments
    (define gi-args-in
      (map (lambda (transform arg) (transform arg)) arguments->gi-arguments arguments))
    (define gi-args-out
      (map (lambda (arg) ((ctype->value->gi-argument _pointer) #f)) (filter (arg-direction? '(o io)) args)))
    (let* ([invocation (g_function_info_invoke info gi-args-in gi-args-out)]
           [return-val (union-ref invocation (or (index-of gi-argument-type-list return-type)
                                                (sub1 (length gi-argument-type-list))))])
      (if (eq? return-type _void)
          (void return-val)
          return-val))))

(define (callable-arguments info)
  (build-list (g_callable_info_get_n_args info)
              (curry g_callable_info_get_arg info)))

(define (arg-direction? dir)
  (lambda (arginfo)
    (let ([direction (g_arg_info_get_direction arginfo)])
      (memq direction dir))))

(define (describe-arguments arguments)
  (define (describe-arg arg)
    (let* ([arg-name (g_base_info_get_name arg)]
           [arg-type (g_arg_info_get_type arg)]
           [arg-type-tag (g_type_info_get_tag arg-type)]
           [arg-direction (g_arg_info_get_direction arg)])
      (format "~v ~a [~a]" arg-type-tag arg-name arg-direction)))
  (map describe-arg arguments))

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

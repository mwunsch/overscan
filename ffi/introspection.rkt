#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc
         racket/class
         (only-in racket/list index-of partition last filter-map)
         (only-in racket/string string-join)
         (only-in racket/function curry curryr))

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))

;;; CTypes
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

(define-cstruct _gerror ([domain _uint32] [code _int] [message _string]))


;;; BaseInfo
(define-gir g_base_info_get_namespace (_fun _gi-base-info -> _string))

(define-gir g_base_info_get_name (_fun _gi-base-info -> _string))

(define-gir g_base_info_get_type (_fun _gi-base-info -> _gi-info-type))

(define-gir g_base_info_unref (_fun _gi-base-info -> _void)
  #:wrap (deallocator))

;;; Repositories
(define-gir g_irepository_require (_fun (_pointer = #f) _string _string _int (err : (_ptr io _gerror-pointer/null) = #f)
                                        -> (r : _pointer)
                                        -> (or r
                                               (error (gerror-message err)))))

(define-gir g_irepository_get_n_infos (_fun (_pointer = #f) _string -> _int))

(define-gir g_irepository_get_info (_fun (_pointer = #f) _string _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_irepository_find_by_name (_fun (_pointer = #f) _string _string -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))


;;; Types
(define-gir g_type_info_get_tag (_fun _gi-base-info -> _gi-type-tag))

(define-gir g_type_info_is_pointer (_fun _gi-base-info -> _bool))

(define-gir g_type_tag_to_string (_fun _gi-type-tag -> _string))

(define-gir g_type_info_get_interface (_fun _gi-base-info -> _gi-base-info))

(define-gir g_info_type_to_string (_fun _gi-info-type -> _string))

(define (describe-gir/type typeinfo)
  (let ([typetag (g_type_info_get_tag typeinfo)])
    (define typestring (if (eq? 'GI_TYPE_TAG_INTERFACE typetag)
                           (g_base_info_get_name (g_type_info_get_interface typeinfo))
                           (g_type_tag_to_string typetag)))
    (string-append typestring (if (g_type_info_is_pointer typeinfo) "*" ""))))


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
      ;; ['GI_TYPE_TAG_GTYPE]
      ;; ['GI_TYPE_TAG_ARRAY]
      ['GI_TYPE_TAG_INTERFACE _pointer]
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

(define (gi-arg->value-of-type giarg typeinfo)
  (let* ([ctype (type-info->ctype typeinfo)]
         [value (union-ref giarg (or (index-of gi-argument-type-list ctype)
                                                (sub1 (length gi-argument-type-list))))])
    (when (cpointer? value)
      (cpointer-push-tag! value (g_base_info_get_name (g_type_info_get_interface typeinfo))))
    (if (eq? ctype _void)
        (void value)
        value)))


;;; Functions & Callables
(define-gir g_callable_info_get_n_args (_fun _gi-base-info -> _int))

(define-gir g_callable_info_get_arg (_fun _gi-base-info _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_callable_info_can_throw_gerror (_fun _gi-base-info -> _bool))

(define-gir g_callable_info_get_return_type (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_callable_info_is_method (_fun _gi-base-info -> _bool))

(define-gir g_arg_info_get_type (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_arg_info_get_direction (_fun _gi-base-info -> _gi-direction))

(struct gir/argument (value type direction))

(define (make-gir/argument arginfo value)
  (define arg-ctype ((compose1 type-info->ctype g_arg_info_get_type) arginfo))
  (gir/argument ((ctype->value->gi-argument arg-ctype) value)
                arg-ctype
                (g_arg_info_get_direction arginfo)))

(define (gir/argument-direction? dir)
  (lambda (argument)
    (memq (gir/argument-direction argument) dir)))

(define-gir g_function_info_get_flags (_fun _gi-base-info -> _gi-function-info-flags))

(define-gir g_function_info_invoke (_fun _gi-base-info
                                         [inargs : (_list i _gi-argument)] [_int = (length inargs)]
                                         [outargs : (_list i _gi-argument)] [_int = (length outargs)]
                                         [r : (_ptr o _gi-argument)]
                                         (err : (_ptr io _gerror-pointer/null) = #f)
                                         -> (invoked : _bool)
                                         -> (if invoked r (error (gerror-message err)))))

(struct gir/function (info args returns)
  #:property prop:procedure
  (lambda (fn . arguments)
    (let* ([funinfo (gir/function-info fn)]
           [arginfos (gir/function-args fn)]
           [return-type (gir/function-returns fn)]
           [method? (g_callable_info_is_method funinfo)]
           [n-args (if method? (add1 (length arginfos)) (length arginfos))])
      (when (not (eqv? (length arguments) n-args))
        (apply raise-arity-error fn n-args arguments))
      (define args (map make-gir/argument arginfos (if (and method? (pair? arguments)) (cdr arguments) arguments)))
      (define-values (args-in args-out)
        (values (map gir/argument-value (filter (gir/argument-direction? '(i io)) args))
                (map gir/argument-value (filter (gir/argument-direction? '(o io)) args))))
      (let* ([args-in (if method?
                          (cons ((ctype->value->gi-argument _pointer) (car arguments)) args-in)
                          args-in)]
             [invocation (g_function_info_invoke funinfo args-in args-out)])
        (gi-arg->value-of-type invocation return-type))))
  #:property prop:cpointer 0)

(define (make-gir/function fninfo)
  (let ([args (build-list (g_callable_info_get_n_args fninfo)
                          (curry g_callable_info_get_arg fninfo))]
        [returns (g_callable_info_get_return_type fninfo)])
    (gir/function fninfo args returns)))

(define (describe-gir/function fn)
  (let* ([funinfo (gir/function-info fn)]
         [arginfos (gir/function-args fn)]
         [returninfo (gir/function-returns fn)]
         [args (map (lambda (arg)
                      (let ([argtype ((compose1 describe-gir/type
                                                g_arg_info_get_type) arg)]
                            [argname (g_base_info_get_name arg)])
                        (format "~a ~a" argtype argname)))
                    arginfos)]
         [return-type (describe-gir/type returninfo)])
    (format "~a (~a) → ~a" (g_base_info_get_name funinfo) (string-join args ", ") return-type)))


;;; Constants
(define-gir g_constant_info_get_type (_fun _gi-base-info -> _gi-base-info))

(define-gir g_constant_info_get_value (_fun _gi-base-info
                                            [r : (_ptr o _gi-argument)]
                                            -> (size : _int)
                                            -> r))

(define (gir/constant info)
  (let ([ctype ((compose1 type-info->ctype
                          g_constant_info_get_type) info)]
        [value (g_constant_info_get_value info)])
    (gi-arg->value-of-type value ctype)))


;;; Structs
(define-gir g_struct_info_get_n_fields (_fun _gi-base-info -> _int))

(define-gir g_struct_info_get_field (_fun _gi-base-info _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_struct_info_get_n_methods (_fun _gi-base-info -> _int))

(define-gir g_struct_info_get_method (_fun _gi-base-info _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_struct_info_find_method (_fun _gi-base-info _string -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(struct gir/struct (info fields methods)
  #:property prop:procedure
  (lambda (structure pointer)
    (let* ([structinfo (gir/struct-info structure)]
           [fields (gir/struct-fields structure)]
           [methods (gir/struct-methods structure)])
      ;; TODO: make-struct-type here
      (lambda (name . args)
        (let ([method (g_struct_info_find_method pointer (symbol->string name))])
          (if method
              (apply (make-gir/function method) pointer args)
              #f)))))
  #:property prop:cpointer 0)

(define (make-gir/struct info)
  (let ([fields (build-list (g_struct_info_get_n_fields info)
                            (curry g_struct_info_get_field info))]
        [methods (build-list (g_struct_info_get_n_methods info)
                             (compose1 make-gir/function
                                       (curry g_struct_info_get_method info)))])
    (gir/struct info fields methods)))

(define (describe-gir/struct strct)
  (let* ([structinfo (gir/struct-info strct)]
         [fields (gir/struct-fields strct)]
         [methodinfos (gir/struct-methods strct)])
    (hash 'fields (map g_base_info_get_name fields)
          'methods (map describe-gir/function methodinfos))))


;;; Objects
(define-gir g_object_info_get_parent (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_object_info_get_class_struct (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(struct gir/object (info fields methods properties signals))

(define (make-gir/object info)
  (letrec ([hierarchy (lambda (infos)
                        (define parentinfo (g_object_info_get_parent (car infos)))
                        (if parentinfo
                            (hierarchy (cons parentinfo infos))
                            infos))])
    (make-gir/struct (g_object_info_get_class_struct info))))


;;; Introspection
(define (introspection-info namespace)
  (g_irepository_require namespace #f 0)
  (for/list ([i (in-range (g_irepository_get_n_infos namespace))])
    (let ([_info (g_irepository_get_info namespace i)])
      (cons (g_base_info_get_type _info) (g_base_info_get_name _info)))))

(define (introspection namesym)
  (let ([namespace (symbol->string namesym)])
    (g_irepository_require namespace #f 0)
    (lambda (name)
      (let ([info (or (g_irepository_find_by_name namespace (symbol->string name))
                      (raise-argument-error 'introspection "name in GIR namespace" name))])
        (gi-binding info)))))

(define (gi-binding info)
  (let ([info-type (g_base_info_get_type info)]
        [info-name (string->symbol (g_base_info_get_name info))])
    (case info-type
      ['GI_INFO_TYPE_FUNCTION (make-gir/function info)]
      ['GI_INFO_TYPE_STRUCT (make-gir/struct info)]
      ;; ['GI_INFO_TYPE_OBJECT (gir/object info)]
      ['GI_INFO_TYPE_CONSTANT (gir/constant info)]
      [else (cons info-type (info-name))])))

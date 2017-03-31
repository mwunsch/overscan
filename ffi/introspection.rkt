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

(struct gi-type (info)
  #:property prop:procedure
  (lambda (type gi-arg)
    (let* ([ctype (gi-type->ctype type)]
           [value (union-ref gi-arg (or (index-of gi-argument-type-list ctype)
                                        (sub1 (length gi-argument-type-list))))])
      (when (cpointer? value)
        (cpointer-push-tag! value
                            ((compose1 g_base_info_get_name
                                       g_type_info_get_interface) type)))
      (if (eq? ctype _void)
          (void value)
          value)))
  #:property prop:cpointer 0)

(define (gi-type-tag type)
  (g_type_info_get_tag type))

(define (gi-type-pointer? type)
  (g_type_info_is_pointer type))

(define (describe-gi-type type)
  (let ([typetag (gi-type-tag type)])
    (define typestring (if (eq? 'GI_TYPE_TAG_INTERFACE typetag)
                           (g_base_info_get_name (g_type_info_get_interface type))
                           (g_type_tag_to_string typetag)))
    (string-append typestring (if (gi-type-pointer? type) "*" ""))))

(define (gi-type->ctype type)
  (let ([typetag (gi-type-tag type)])
    (case typetag
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

(define (ctype->_gi-argument ctype value)
  (let* ([gi-argument-pointer (malloc _gi-argument)]
         [union-val (ptr-ref gi-argument-pointer _gi-argument)]
         [index (or (index-of gi-argument-type-list ctype)
                    (sub1 (length gi-argument-type-list)))])
    (union-set! union-val index value)
    union-val))


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

(struct gi-arg (info)
  #:property prop:procedure
  (lambda (arg value)
    (gi-arg->_gi-argument arg value))
  #:property prop:cpointer 0)

(define (gi-arg-type arg)
  (gi-type (g_arg_info_get_type arg)))

(define (gi-arg-direction arg)
  (g_arg_info_get_direction arg))

(define (gi-arg-direction? arg dir)
  (memq (gi-arg-direction arg) dir))

(define (gi-arg->_gi-argument arg value)
  (let* ([ctype ((compose1 gi-type->ctype gi-arg-type) arg)])
    (ctype->_gi-argument ctype value)))

(define (describe-gi-arg arg)
  (let ([argtype (gi-arg-type arg)]
        [argname (g_base_info_get_name arg)])
    (format "~a ~a"
            (describe-gi-type argtype)
            argname)))

(define-gir g_function_info_get_flags (_fun _gi-base-info -> _gi-function-info-flags))

(define-gir g_function_info_invoke (_fun _gi-base-info
                                         [inargs : (_list i _gi-argument)] [_int = (length inargs)]
                                         [outargs : (_list i _gi-argument)] [_int = (length outargs)]
                                         [r : (_ptr o _gi-argument)]
                                         (err : (_ptr io _gerror-pointer/null) = #f)
                                         -> (invoked : _bool)
                                         -> (if invoked r (error (gerror-message err)))))

(struct gi-function (info)
  #:property prop:procedure
  (lambda (fn . arguments)
    (let ([args (gi-function-args fn)]
          [returns (gi-function-returns fn)]
          [method? (gi-function-method? fn)]
          [arity (gi-function-arity fn)])
      (unless (eqv? (length arguments) arity)
        (apply raise-arity-error fn arity arguments))
      (define arguments-without-self
        (if (and method? (pair? arguments))
            (cdr arguments)
            arguments))
      (define _gi-args-direction-pairs
        (map (lambda (arg value) (cons (arg value) (gi-arg-direction arg)))
             args
             arguments-without-self))
      (define-values (in-args-without-self out-args)
        (values (filter-map (lambda (pair) (and (memq (cdr pair) '(i io))
                                           (car pair))) _gi-args-direction-pairs)
                (filter-map (lambda (pair) (and (memq (cdr pair) '(o io))
                                           (car pair))) _gi-args-direction-pairs)))
      (define in-args
        (if method?
            (cons (ctype->_gi-argument _pointer (car arguments)) in-args-without-self)
            in-args-without-self))
      (returns (g_function_info_invoke fn in-args out-args))))
  #:property prop:cpointer 0)

(define (gi-function-method? fn)
  (g_callable_info_is_method fn))

(define (gi-function-args fn)
  (build-list (g_callable_info_get_n_args fn)
              (compose1 gi-arg (curry g_callable_info_get_arg fn))))

(define (gi-function-arity fn)
  (let ([args (gi-function-args fn)])
    (if (gi-function-method? fn)
        (add1 (length args))
        (length args))))

(define (gi-function-returns fn)
  (gi-type (g_callable_info_get_return_type fn)))

(define (describe-gi-function fn)
  (let ([name (g_base_info_get_name fn)]
        [args (map describe-gi-arg (gi-function-args fn))]
        [returns (describe-gi-type (gi-function-returns fn))])
    (format "~a (~a) → ~a" name (string-join args ", ") returns)))


;;; Constants
(define-gir g_constant_info_get_type (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_constant_info_get_value (_fun _gi-base-info
                                            [r : (_ptr o _gi-argument)]
                                            -> (size : _int)
                                            -> r))

(struct gi-constant (info)
  #:property prop:procedure
  (lambda (constant)
    (gi-constant-value constant))
  #:property prop:cpointer 0)

(define (gi-constant-type constant)
  (gi-type (g_constant_info_get_type constant)))

(define (gi-constant-value constant)
  (let ([type (gi-constant-type constant)])
    (type (g_constant_info_get_value constant))))

(define (describe-gi-constant constant)
  (g_base_info_get_name constant))


;;; Structs
(define-gir g_struct_info_get_n_fields (_fun _gi-base-info -> _int))

(define-gir g_struct_info_get_field (_fun _gi-base-info _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_struct_info_get_n_methods (_fun _gi-base-info -> _int))

(define-gir g_struct_info_get_method (_fun _gi-base-info _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_struct_info_find_method (_fun _gi-base-info _string -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(struct gi-struct (info)
  #:property prop:procedure
  (lambda (structure pointer)
    (lambda (name)
      (let ([method (gi-struct-find-method structure name)])
        (curry method pointer))))
  #:property prop:cpointer 0)

(define (gi-struct-fields structure)
  (build-list (g_struct_info_get_n_fields structure)
              (curry g_struct_info_get_field structure)))

(define (gi-struct-methods structure)
  (build-list (g_struct_info_get_n_methods structure)
              (compose1 gi-function
                        (curry g_struct_info_get_method structure))))

(define (gi-struct-find-method structure method)
  (let ([found-method (g_struct_info_find_method structure method)])
    (if found-method
        (gi-function found-method)
        (raise-argument-error 'gi-struct-find-method "struct-method?" method))))

(define (describe-gi-struct structure)
  (hash 'fields (map g_base_info_get_name (gi-struct-fields structure))
        'methods (map describe-gi-function (gi-struct-methods structure))))


;;; Objects
(define-gir g_object_info_get_parent (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_object_info_get_class_struct (_fun _gi-base-info -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

;; (struct gir/object (info fields methods properties signals))

;; (define (make-gir/object info)
;;   (letrec ([hierarchy (lambda (infos)
;;                         (define parentinfo (g_object_info_get_parent (car infos)))
;;                         (if parentinfo
;;                             (hierarchy (cons parentinfo infos))
;;                             infos))])
;;     (make-gir/struct (g_object_info_get_class_struct info))))


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
      ['GI_INFO_TYPE_FUNCTION (gi-function info)]
      ['GI_INFO_TYPE_STRUCT (gi-struct info)]
      ;; ['GI_INFO_TYPE_OBJECT (gir/object info)]
      ['GI_INFO_TYPE_CONSTANT (gi-constant info)]
      [else (cons info-type (info-name))])))

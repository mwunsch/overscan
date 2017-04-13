#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc
         racket/class
         (only-in racket/list index-of filter-map)
         (only-in racket/string string-join)
         (only-in racket/function curry curryr)
         (for-syntax racket/base))

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))

;;; CTypes
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

(define _gi-function-info-flags (_bitmask '(method?
                                            constructor?
                                            getter?
                                            setter?
                                            wraps?
                                            throws?)))

(define gi-argument-type-list (list _bool _int8 _uint8 _int16 _uint16 _int32 _uint32
                                    _int64 _uint64 _float _double
                                    _short _ushort _int _uint _long _ulong _ssize _size
                                    _string _pointer))

(define _gi-argument (apply _union gi-argument-type-list))

(define _gi-direction (_enum '(in out inout)))

(define _gtype (make-ctype _size #f #f))

(define-cstruct _gerror ([domain _uint32] [code _int] [message _string]))


;;; BaseInfo
(struct gi-base (info)
  #:property prop:cpointer 0)

(define (make-gi-base info-pointer)
  (let* ([base (gi-base info-pointer)]
         [type (gi-base-type base)])
    (case type
      ['GI_INFO_TYPE_FUNCTION (gi-function base)]
      ['GI_INFO_TYPE_STRUCT (gi-struct base)]
      ['GI_INFO_TYPE_ENUM (gi-enum base)]
      ['GI_INFO_TYPE_CONSTANT (gi-constant base)]
      ['GI_INFO_TYPE_VALUE (gi-value base)]
      ['GI_INFO_TYPE_FIELD (gi-field base)]
      ['GI_INFO_TYPE_ARG (gi-arg base)]
      ['GI_INFO_TYPE_TYPE (gi-type base)]
      [else base])))

(define _gi-base-info (_cpointer/null 'GIBaseInfo _pointer values make-gi-base))

(define-gir gi-base-namespace (_fun _gi-base-info -> _string)
  #:c-id g_base_info_get_namespace)

(define-gir gi-base-name (_fun _gi-base-info -> _string)
  #:c-id g_base_info_get_name)

(define-gir gi-base-type (_fun _gi-base-info -> _gi-info-type)
  #:c-id g_base_info_get_type)

(define-gir g_base_info_unref (_fun _gi-base-info -> _void)
  #:wrap (deallocator))

;;; Repositories
(define-gir g_irepository_require (_fun (_pointer = #f) _symbol _string _int (err : (_ptr io _gerror-pointer/null) = #f)
                                        -> (r : _pointer)
                                        -> (or r
                                               (error (gerror-message err)))))

(define-gir g_irepository_get_n_infos (_fun (_pointer = #f) _symbol -> _int))

(define-gir g_irepository_get_info (_fun (_pointer = #f) _symbol _int -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_irepository_find_by_name (_fun (_pointer = #f) _symbol _symbol -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))

(define-gir g_irepository_find_by_gtype (_fun (_pointer = #f) _gtype -> _gi-base-info)
  #:wrap (allocator g_base_info_unref))


;;; Types
(struct gi-type gi-base ()
  #:property prop:procedure
  (lambda (type gi-arg)
    (let* ([ctype (gi-type->ctype type)])
      (_gi-argument->ctype gi-arg ctype))))

(define-gir gi-type-tag (_fun _gi-base-info -> _gi-type-tag)
  #:c-id g_type_info_get_tag)

(define-gir gi-type-pointer? (_fun _gi-base-info -> _bool)
  #:c-id g_type_info_is_pointer)

(define-gir g_type_tag_to_string (_fun _gi-type-tag -> _string))

(define-gir gi-type-interface (_fun _gi-base-info -> _gi-base-info)
  #:c-id g_type_info_get_interface
  #:wrap (allocator g_base_info_unref))

(define-gir g_info_type_to_string (_fun _gi-info-type -> _string))

(define (describe-gi-type type)
  (let ([typetag (gi-type-tag type)])
    (define typestring (if (eq? 'GI_TYPE_TAG_INTERFACE typetag)
                           (gi-base-name (gi-type-interface type))
                           (g_type_tag_to_string typetag)))
    (string-append typestring (if (gi-type-pointer? type) "*" ""))))

(define (gi-type->ctype type)
  (let* ([typetag (gi-type-tag type)]
         [tagsym (string->symbol (g_type_tag_to_string typetag))])
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
      ['GI_TYPE_TAG_INTERFACE (let* ([type-interface (gi-type-interface type)]
                                     [info-type (gi-base-type type-interface)])
                                (cond
                                  [(gi-struct? type-interface)
                                   (gi-struct->ctype type-interface)]
                                  [(gi-enum? type-interface)
                                   (gi-enum->ctype type-interface)]
                                  [(gi-registered-type? type-interface)
                                   (gi-registered-type->ctype type-interface)]
                                  [else (_cpointer/null info-type)]))]
      ['GI_TYPE_TAG_ERROR _gerror-pointer]
      ;; ['GI_TYPE_TAG_GTYPE]
      ;; ['GI_TYPE_TAG_ARRAY]
      ;; ['GI_TYPE_TAG_GLIST]
      ;; ['GI_TYPE_TAG_GSLIST]
      ;; ['GI_TYPE_TAG_GHASH]
      ;; ['GI_TYPE_TAG_UNICHAR]
      [else (_cpointer/null tagsym)])))

(define (ctype->_gi-argument ctype value)
  (let* ([gi-argument-pointer (malloc _gi-argument)]
         [union-val (ptr-ref gi-argument-pointer _gi-argument)]
         [_arg-type (_gi-argument-type-of ctype)]
         [index (_gi-argument-index-of ctype)])
    (union-set! union-val index (if (eq? _arg-type ctype)
                                    value
                                    (cast value ctype _arg-type)))
    union-val))

(define (gi-type->_gi-argument type value)
  (ctype->_gi-argument (gi-type->ctype type) value))

(define (_gi-argument->ctype gi-arg ctype)
  (let* ([index (_gi-argument-index-of ctype)]
         [_arg-type (_gi-argument-type-of ctype)]
         [value (union-ref gi-arg index)])
    (cond
      [(eq? ctype _void) (void value)]
      [(not (eq? _arg-type ctype)) (cast value _arg-type ctype)]
      [else value])))

(define (_gi-argument-index-of ctype)
  (define _gi-argument-type (_gi-argument-type-of ctype))
  (or (index-of gi-argument-type-list _gi-argument-type)
      (sub1 (length gi-argument-type-list))))

(define (_gi-argument-type-of ctype)
  (if (member ctype gi-argument-type-list)
      ctype
      (case (ctype->layout ctype)
        ['bool _bool]
        ['int8 _int8]
        ['uint8 _uint8]
        ['int16 _int16]
        ['uint16 _uint16]
        ['int32 _int32]
        ['uint32 _uint32]
        ['int64 _int64]
        ['uint64 _uint64]
        ['float _float]
        ['double _double]
        ['bytes _string]
        [else _pointer])))


;;; Functions & Callables
(struct gi-callable gi-base ())

(define-gir gi-callable-n-args (_fun _gi-base-info -> _int)
  #:c-id g_callable_info_get_n_args)

(define-gir gi-callable-arg (_fun _gi-base-info _int
                                  -> _gi-base-info)
  #:c-id g_callable_info_get_arg
  #:wrap (allocator g_base_info_unref))

(define (gi-callable-args fn)
  (build-list (gi-callable-n-args fn)
              (curry gi-callable-arg fn)))

(define-gir gi-callable-throws? (_fun _gi-base-info -> _bool)
  #:c-id g_callable_info_can_throw_gerror)

(define-gir gi-callable-returns (_fun _gi-base-info
                                      -> _gi-base-info)
  #:c-id g_callable_info_get_return_type
  #:wrap (allocator g_base_info_unref))

(define-gir gi-callable-method? (_fun _gi-base-info -> _bool)
  #:c-id g_callable_info_is_method)

(define (gi-callable-arity fn)
  (let ([args (gi-callable-args fn)])
    (if (gi-callable-method? fn)
        (add1 (length args))
        (length args))))

(struct gi-arg gi-base ()
  #:property prop:procedure
  (lambda (arg value)
    (gi-arg->_gi-argument arg value)))

(define-gir gi-arg-type (_fun _gi-base-info
                              -> _gi-base-info)
  #:c-id g_arg_info_get_type
  #:wrap (allocator g_base_info_unref))

(define-gir gi-arg-direction (_fun _gi-base-info -> _gi-direction)
  #:c-id g_arg_info_get_direction)

(define (gi-arg-direction? arg dir)
  (memq (gi-arg-direction arg) dir))

(define (gi-arg->_gi-argument arg value)
  (gi-type->_gi-argument (gi-arg-type arg) value))

(define (describe-gi-arg arg)
  (let ([argtype (gi-arg-type arg)]
        [argname (gi-base-name arg)])
    (format "~a ~a"
            (describe-gi-type argtype)
            argname)))

(define-gir gi-function-flags (_fun _gi-base-info -> _gi-function-info-flags)
  #:c-id g_function_info_get_flags)

(define-gir gi-function-invoke (_fun _gi-base-info
                                     [inargs : (_list i _gi-argument)] [_int = (length inargs)]
                                     [outargs : (_list i _gi-argument)] [_int = (length outargs)]
                                     [r : (_ptr o _gi-argument)]
                                     (err : (_ptr io _gerror-pointer/null) = #f)
                                     -> (invoked : _bool)
                                     -> (if invoked r (error (gerror-message err))))
  #:c-id g_function_info_invoke)

(struct gi-function gi-callable ()
  #:property prop:procedure
  (lambda (fn . arguments)
    (let ([args (gi-callable-args fn)]
          [returns (gi-callable-returns fn)]
          [method? (gi-callable-method? fn)]
          [arity (gi-callable-arity fn)])
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
        (values (filter-map (lambda (pair) (and (memq (cdr pair) '(in inout))
                                           (car pair))) _gi-args-direction-pairs)
                (filter-map (lambda (pair) (and (memq (cdr pair) '(out inout))
                                           (car pair))) _gi-args-direction-pairs)))
      (define in-args
        (if method?
            (cons (ctype->_gi-argument _pointer (car arguments)) in-args-without-self)
            in-args-without-self))
      (returns (gi-function-invoke fn in-args out-args)))))

(define (describe-gi-function fn)
  (let ([name (gi-base-name fn)]
        [args (map describe-gi-arg (gi-callable-args fn))]
        [returns (describe-gi-type (gi-callable-returns fn))])
    (format "~a (~a) → ~a" name (string-join args ", ") returns)))


;;; Constants
(struct gi-constant gi-base ()
  #:property prop:procedure
  (lambda (constant)
    (gi-constant-value constant)))

(define-gir gi-constant-type (_fun _gi-base-info
                                   -> _gi-base-info)
  #:c-id g_constant_info_get_type
  #:wrap (allocator g_base_info_unref))

(define-gir g_constant_info_free_value (_fun _gi-base-info (_ptr i _gi-argument) -> _void)
  #:wrap (deallocator cadr))

(define-gir g_constant_info_get_value (_fun _gi-base-info
                                            [r : (_ptr o _gi-argument)]
                                            -> (size : _int)
                                            -> r)
  #:wrap (allocator g_constant_info_free_value))

(define (gi-constant-value constant)
  (let ([type (gi-constant-type constant)])
    (type (g_constant_info_get_value constant))))

(define (describe-gi-constant constant)
  (gi-base-name constant))


;;; Registered Types
(struct gi-registered-type gi-base ())

(define-gir gi-registered-type-name (_fun _gi-base-info -> _symbol)
  #:c-id g_registered_type_info_get_type_name)

(define-gir gi-registered-type-gtype (_fun _gi-base-info -> _gtype)
  #:c-id g_registered_type_info_get_g_type)

(define (gi-registered-type-sym registered)
  (let* ([name (gi-base-name registered)]
         [dashed (regexp-replace* #rx"([a-z]+)([A-Z]+)" name "\\1-\\2")])
    ((compose1 string->symbol string-downcase) dashed)))

(struct gtype-instance (type pointer)
  #:property prop:cpointer 1)

(define (gi-registered-type->ctype registered)
  (let* ([name (gi-registered-type-sym registered)])
    (_cpointer name _pointer
               values
               (curry gtype-instance registered))))

;;; Structs
(struct gi-struct gi-registered-type ())

(struct gstruct-instance gtype-instance (fields)
  #:transparent
  #:property prop:procedure
  (lambda (instance method-name . arguments)
    (let* ([base (gtype-instance-type instance)])
      (apply (gi-struct-find-method base method-name)
             instance
             arguments))))

(define (gi-struct->ctype structure)
  (let* ([name (gi-registered-type-sym structure)]
         [fields (gi-struct-fields structure)])
    (_cpointer name _pointer
               values
               (lambda (ptr)
                 (let ([field-values (map (curryr gi-field-ref ptr) fields)])
                   (gstruct-instance structure ptr field-values))))))

(define-gir gi-struct-alignment (_fun _gi-base-info -> _size)
  #:c-id g_struct_info_get_alignment)

(define-gir gi-struct-size (_fun _gi-base-info -> _size)
  #:c-id g_struct_info_get_size)

(define-gir gi-struct-n-fields (_fun _gi-base-info -> _int)
  #:c-id g_struct_info_get_n_fields)

(define-gir gi-struct-field (_fun _gi-base-info _int
                                  -> _gi-base-info)
  #:c-id g_struct_info_get_field
  #:wrap (allocator g_base_info_unref))

(struct gi-field gi-base ()
  #:property prop:procedure
  (lambda (field value)
    (gi-type->_gi-argument (gi-field-type field) value)))

(define (gi-struct-fields structure)
  (build-list (gi-struct-n-fields structure)
              (curry gi-struct-field structure)))

(define-gir gi-field-type (_fun _gi-base-info
                                -> _gi-base-info)
  #:c-id g_field_info_get_type
  #:wrap (allocator g_base_info_unref))

(define-gir gi-field-ref (_fun [field : _gi-base-info] _pointer
                               [r : (_ptr o _gi-argument)]
                               -> (success? : _bool)
                               -> (if success?
                                      (let ([type (gi-field-type field)])
                                        (type r))
                                      (error "oh no")))
  #:c-id g_field_info_get_field)

(define-gir gi-field-set! (_fun [field : _gi-base-info] _pointer
                                [arg : _?]
                                [r : (_ptr i _gi-argument) = (field arg)]
                                -> (success? : _bool)
                                -> (if success? (void) (error "oh no")))
  #:c-id g_field_info_set_field)

(define (describe-gi-field field)
  (format "~a ~a"
          (describe-gi-type (gi-field-type field))
          (gi-base-name field)))

(define-gir gi-struct-n-methods (_fun _gi-base-info -> _int)
  #:c-id g_struct_info_get_n_methods)

(define-gir gi-struct-method (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_struct_info_get_method
  #:wrap (allocator g_base_info_unref))

(define (gi-struct-methods structure)
  (build-list (gi-struct-n-methods structure)
              (curry gi-struct-method structure)))

(define-gir gi-struct-find-method (_fun _gi-base-info (method : _symbol)
                                        -> (res : _gi-base-info)
                                        -> (or res
                                               (raise-argument-error 'gi-struct-find-method "struct-method?" method)))
  #:c-id g_struct_info_find_method
  #:wrap (allocator g_base_info_unref))

(define (describe-gi-struct structure)
  (define fields (string-join (map describe-gi-field (gi-struct-fields structure))
                              "\n  "))
  (define methods (string-join (map describe-gi-function (gi-struct-methods structure))
                               "\n  "))
  (format "struct ~a {~n  ~a ~n~n  ~a ~n}" (gi-base-name structure) fields methods))


;;; Enums
(struct gi-enum gi-registered-type ())

(define-gir gi-enum-n-values (_fun _gi-base-info -> _int)
  #:c-id g_enum_info_get_n_values)

(define-gir gi-enum-value (_fun _gi-base-info _int
                                -> _gi-base-info)
  #:c-id g_enum_info_get_value
  #:wrap (allocator g_base_info_unref))

(define-gir gi-enum-storage-type (_fun _gi-base-info ->
                                       [tag : _gi-type-tag]
                                       -> (case tag
                                            ['GI_TYPE_TAG_INT8 _int8]
                                            ['GI_TYPE_TAG_UINT8 _uint8]
                                            ['GI_TYPE_TAG_INT16 _int16]
                                            ['GI_TYPE_TAG_UINT16 _uint16]
                                            ['GI_TYPE_TAG_INT32 _int32]
                                            ['GI_TYPE_TAG_UINT32 _uint32]
                                            ['GI_TYPE_TAG_INT64 _int64]
                                            ['GI_TYPE_TAG_UINT64 _uint64]
                                            [else _int64]))
  #:c-id g_enum_info_get_storage_type)

(struct gi-value gi-base ()
  #:property prop:procedure
  (compose1 string->symbol gi-base-name))

(define-gir gi-value-get (_fun _gi-base-info
                               -> _int)
  #:c-id g_value_info_get_value)

(define (gi-enum-values enum)
  (build-list (gi-enum-n-values enum)
              (curry gi-enum-value enum)))

(define (gi-enum->list enum)
  (map (lambda (val) (val))
       (gi-enum-values enum)))

(define (gi-enum->hash enum)
  (make-hash (map (lambda (val) (cons (gi-value-get val) (val)))
                  (gi-enum-values enum))))

(define-gir gi-enum-n-methods (_fun _gi-base-info -> _int)
  #:c-id g_enum_info_get_n_methods)

(define-gir gi-enum-method (_fun _gi-base-info _int
                                 -> _gi-base-info)
  #:c-id g_enum_info_get_method
  #:wrap (allocator g_base_info_unref))

(define (gi-enum-methods enum)
  (build-list (gi-enum-n-methods enum)
              (curry gi-enum-value enum)))

(define (gi-enum->ctype enum)
  (let* ([enum-hash (gi-enum->hash enum)])
    (make-ctype _int64
                (lambda (val)
                  (for/first ([k+v (in-hash-pairs enum-hash)]
                              #:when (eq? val (cdr k+v)))
                    (car k+v)))
                (curry hash-ref enum-hash))))


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
      (cons (gi-base-type _info) (gi-base-name _info)))))

(define (introspection namespace)
  (g_irepository_require namespace #f 0)
  (lambda (name)
    (or (g_irepository_find_by_name namespace name)
        (raise-argument-error 'introspection "name in GIR namespace" name))))

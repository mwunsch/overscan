#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/alloc
         ffi/cvector
         (rename-in racket/contract [-> ->>])
         (only-in racket/list index-of filter-map make-list)
         (only-in racket/string string-join string-replace)
         (only-in racket/function curry curryr thunk)
         (for-syntax racket/base
                     racket/syntax
                     syntax/parse
                     (only-in racket/string string-replace)))

(provide (contract-out [struct gi-base
                               ((info cpointer?))
                               #:omit-constructor]
                       [gi-base-name
                        (->> gi-base? symbol?)]
                       [gi-base=?
                        (->> gi-base? gi-base? boolean?)]
                       [gi-function?
                        (->> any/c boolean?)]
                       [gi-registered-type?
                        (->> any/c boolean?)]
                       [gi-enum?
                        (->> any/c boolean?)]
                       [gi-enum->list
                        (->> gi-enum? list?)]
                       [gi-enum->hash
                        (->> gi-enum? hash?)]
                       [gi-object?
                        (->> any/c boolean?)]
                       [gi-struct?
                        (->> any/c boolean?)]
                       [_gi-object
                        (->> gi-object? ctype?)]
                       [struct gtype-instance
                               ((type gi-registered-type?) (pointer cpointer?))
                               #:omit-constructor]
                       [gtype-instance-type-name
                        (->> gtype-instance? symbol?)]
                       [gtype-instance-name
                        (->> gtype-instance? symbol?)]
                       [is-a?
                        (->> gtype-instance? gi-registered-type? boolean?)]
                       [is-a?/c
                        (->> gi-registered-type? flat-contract?)]
                       [struct (gstruct gtype-instance)
                               ((type gi-struct?) (pointer cpointer?))
                               #:omit-constructor]
                       [struct (gobject gtype-instance)
                               ((type gi-object?) (pointer cpointer?))
                               #:omit-constructor]
                       [dynamic-send
                        (->* ((or/c gobject? gstruct?) symbol?) #:rest (listof any/c) any)]
                       [dynamic-get-field
                        (->> symbol? (or/c gobject? gstruct?) any)]
                       [dynamic-set-field!
                        (->> symbol? (or/c gobject? gstruct?) any/c void?)]
                       [method-names
                        (->> (or/c gobject? gstruct?) (listof symbol?))]
                       [describe-method
                        (->> gobject? symbol? string?)]
                       [connect
                        (->* (gobject? symbol? procedure?)
                             (#:data cpointer?
                                     #:cast (or/c ctype? gi-object?))
                             exact-integer?)]
                       [gobject-cast
                        (->> cpointer? gi-object? gobject?)]
                       [gstruct-cast
                        (->> cpointer? gi-struct? gstruct?)]
                       [gobject-get
                        (->> gobject? string? ctype? any)]
                       [gobject-set!
                        (->* (gobject? string? any/c)
                             ((or/c ctype? (listof symbol?)))
                             void?)]
                       [gobject-with-properties
                        (->> gobject? (hash/c symbol? any/c) gobject?)]
                       [introspection
                        (->* (symbol?) (string?) gi-repository?)]
                       [struct gi-repository
                               ([namespace symbol?] [version string?] [info-hash (hash/c symbol? gi-base?)])
                               #:omit-constructor]
                       [gi-repository-find-name
                        (->> gi-repository? symbol? gi-base?)]
                       [gi-repository->ffi-lib
                        (->> gi-repository? ffi-lib?)])
         send get-field set-field! field-bound? responds-to?
         describe-gi-function
         gir-member/c gi-repository-member/c)

(define-ffi-definer define-gir (ffi-lib "libgirepository-1.0"))
(define libgobject (ffi-lib "libgobject-2.0"))
(define-ffi-definer define-gobject libgobject)

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
      [(GI_INFO_TYPE_ENUM GI_INFO_TYPE_FLAGS) (gi-enum base)]
      ['GI_INFO_TYPE_OBJECT (gi-object base)]
      ['GI_INFO_TYPE_CONSTANT (gi-constant base)]
      ['GI_INFO_TYPE_VALUE (gi-value base)]
      ['GI_INFO_TYPE_SIGNAL (gi-signal base)]
      ['GI_INFO_TYPE_PROPERTY (gi-property base)]
      ['GI_INFO_TYPE_FIELD (gi-field base)]
      ['GI_INFO_TYPE_ARG (gi-arg base)]
      ['GI_INFO_TYPE_TYPE (gi-type base)]
      [else base])))

(define _gi-base-info (_cpointer/null 'GIBaseInfo _pointer
                                      values
                                      (lambda (cval)
                                        (and cval
                                            (((allocator gi-base-unref!) make-gi-base) cval)))))

(define-gir gi-base-namespace (_fun _gi-base-info -> _string)
  #:c-id g_base_info_get_namespace)

(define-gir gi-base-name (_fun _gi-base-info -> _symbol)
  #:c-id g_base_info_get_name)

(define-gir gi-base=? (_fun _gi-base-info _gi-base-info -> _bool)
  #:c-id g_base_info_equal)

(define (gi-base-sym info)
  (let* ([name (gi-base-name info)]
         [dashed (regexp-replace* #rx"([a-z]+)([A-Z]+)" (symbol->string name) "\\1-\\2")])
    ((compose1 string->symbol
               (curryr string-replace "_" "-")
               string-downcase) dashed)))

(define-gir gi-base-type (_fun _gi-base-info -> _gi-info-type)
  #:c-id g_base_info_get_type)

(define-gir gi-base-unref! (_fun _gi-base-info -> _void)
  #:wrap (deallocator)
  #:c-id g_base_info_unref)

(define (gi-build-list info numproc getter)
  (build-list (numproc info)
              (curry getter info)))


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
  #:c-id g_type_info_get_interface)

(define-gir g_info_type_to_string (_fun _gi-info-type -> _string))

(define (gi-type-array? type)
  (eq? (gi-type-tag type) 'GI_TYPE_TAG_ARRAY))

(define-gir gi-type-array-length (_fun _gi-base-info -> _int)
  #:c-id g_type_info_get_array_length)

(define-gir gi-type-array-fixed-size (_fun _gi-base-info -> _int)
  #:c-id g_type_info_get_array_fixed_size)

(define-gir gi-type-param-type (_fun _gi-base-info _int -> _gi-base-info)
  #:c-id g_type_info_get_param_type)

(define-gir gi-type-zero-terminated? (_fun _gi-base-info -> _bool)
  #:c-id g_type_info_is_zero_terminated)

(define-gir gi-type-array-type (_fun _gi-base-info -> (_enum '(carray
                                                               garray
                                                               ptr-array
                                                               byte-array)))
  #:c-id g_type_info_get_array_type)

(define (gi-type-gobject? type)
  (and (eq? 'GI_TYPE_TAG_INTERFACE (gi-type-tag type))
       (gi-object? (gi-type-interface type))))

(define (describe-gi-type type)
  (let ([typetag (gi-type-tag type)])
    (define typestring (if (eq? 'GI_TYPE_TAG_INTERFACE typetag)
                           (symbol->string (gi-base-name (gi-type-interface type)))
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
                                   (_gi-struct type-interface)]
                                  [(gi-enum? type-interface)
                                   (gi-enum->ctype type-interface)]
                                  [(gi-object? type-interface)
                                   (_gi-object type-interface)]
                                  [(gi-registered-type? type-interface)
                                   (gi-registered-type->ctype type-interface)]
                                  [else (_cpointer/null info-type)]))]
      ['GI_TYPE_TAG_ERROR _gerror-pointer]
      ['GI_TYPE_TAG_GTYPE _gtype]
      ['GI_TYPE_TAG_ARRAY (_garray type)]
      ['GI_TYPE_TAG_GLIST (_glist type)]
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

(define (gi-type-malloc type [val #f])
  (let* ([ctype (gi-type->ctype type)]
         [ptr (malloc ctype)])
    (if val
        (and (ptr-set! ptr ctype val)
             ptr)
        ptr)))

(define (_gi-argument->ctype gi-arg ctype)
  (let* ([index (_gi-argument-index-of ctype)]
         [_arg-type (_gi-argument-type-of ctype)]
         [value (union-ref gi-arg index)])
    (cond
      [(eq? ctype _void) (void value)]
      [(not (eq? _arg-type ctype)) (cast value _arg-type ctype)]
      [else value])))

(define (_garray type)
  (let ([size (gi-type-array-length type)]
        [_paramtype (gi-type->ctype (gi-type-param-type type 0))]
        [zero-term? (gi-type-zero-terminated? type)])
    (if (eq? _paramtype _void)
        _void             ; An array of void should be treated as void
        (_cpointer/null (gi-type-array-type type)
                        _pointer
                        (lambda (vec)
                          (and vec
                               (let ([ptr (cvector-ptr (list->cvector (vector->list vec)
                                                                      _paramtype))])
                                 (cpointer-push-tag! ptr (gi-type-array-type type))
                                 ptr)))
                        (lambda (ptr)
                          (and ptr
                               (cond
                                 [(positive? size)
                                  (ptr-ref ptr (_array/vector _paramtype size))]
                                 [zero-term?
                                  (let deref ([offset 0]
                                              [block null])
                                    (define val (ptr-ref ptr _paramtype offset))
                                    (if val
                                        (deref (add1 offset) (list* val block))
                                        (list->vector block)))]
                                 [else (vector)])))))))

(define (_glist type)
  (let ([_paramtype (gi-type->ctype (gi-type-param-type type 0))])
    (_cpointer/null 'GList _pointer
                    (lambda (vals)
                      (let loop ([element #f]
                                 [data vals])
                        (if (null? (cdr data))
                            element
                            (loop (g_list_prepend element (car data))
                                  (cdr data)))))
                    (lambda (ptr)
                      (let loop ([index 0])
                        (let ([data (g_list_nth_data ptr index)])
                          (if data
                              (cons (cast data _pointer _paramtype) (loop (add1 index)))
                              null)))))))

(define-gobject g_list_nth_data (_fun _pointer _int -> _pointer))

(define-gobject g_list_prepend (_fun _pointer _pointer -> _pointer))

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
  #:c-id g_callable_info_get_arg)

(define (gi-callable-args fn)
  (gi-build-list fn gi-callable-n-args gi-callable-arg))

(define-gir gi-callable-throws? (_fun _gi-base-info -> _bool)
  #:c-id g_callable_info_can_throw_gerror)

(define-gir gi-callable-returns (_fun _gi-base-info
                                      -> _gi-base-info)
  #:c-id g_callable_info_get_return_type)

(define-gir gi-callable-method? (_fun _gi-base-info -> _bool)
  #:c-id g_callable_info_is_method)

(define-gir gi-callable-caller-owns (_fun _gi-base-info ->
                                          (_enum '(nothing container everything)))
  #:c-id g_callable_info_get_caller_owns)

(define (gi-callable-arity fn)
  (let* ([args (gi-callable-args fn)]
         [in-args (filter (curryr gi-arg-direction? '(in inout)) args)])
    (if (gi-callable-method? fn)
        (add1 (length in-args))
        (length in-args))))

(struct gi-arg gi-base ()
  #:property prop:procedure
  (lambda (arg value)
    (gi-arg->_gi-argument arg value)))

(define-gir gi-arg-type (_fun _gi-base-info
                              -> _gi-base-info)
  #:c-id g_arg_info_get_type)

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

(define-gir gi-function-invoke (_fun [fn : _gi-base-info]
                                     [inargs : (_list i _gi-argument)] [_int = (length inargs)]
                                     [outargs : (_list i _gi-argument)] [n-out : _int = (length outargs)]
                                     [r : (_ptr o _gi-argument)]
                                     (err : (_ptr io _gerror-pointer/null) = #f)
                                     -> (invoked : _bool)
                                     -> (if invoked
                                            (apply values
                                                   (let ([returns (gi-callable-returns fn)]
                                                         [ownership (gi-callable-caller-owns fn)])
                                                     (cond
                                                       [(and (eq? ownership 'everything)
                                                             (gi-type-gobject? returns))
                                                        (((allocator gobject-unref!) returns) r)]
                                                       [else (returns r)]))
                                                   (if outargs
                                                       (for/list ([union-val (in-array (ptr-ref outargs (_array _gi-argument n-out)))]
                                                                  [outarg (gi-function-outbound-args fn)])
                                                         (if (eq? (gi-arg-direction outarg) 'out)
                                                             (let ([ptr (union-ref union-val (_gi-argument-index-of _pointer))])
                                                               (ptr-ref ptr (gi-type->ctype (gi-arg-type outarg))))
                                                             ((gi-arg-type outarg) union-val)))
                                                       null))
                                            (error (gerror-message err))))
  #:c-id g_function_info_invoke)

(struct gi-function gi-callable ()
  #:property prop:procedure
  (lambda (fn . arguments)
    (let ([args (gi-callable-args fn)]
          [returns (gi-callable-returns fn)]
          [method? (gi-callable-method? fn)]
          [arity (gi-callable-arity fn)])
      (unless (eqv? (length arguments) arity)
        (apply raise-arity-error (gi-base-name fn) arity arguments))

      (define args+values
        (let* ([arglength (length args)]
               [arguments (if (and method? (pair? arguments))
                              (cdr arguments)
                              arguments)]
               [vals (append arguments (make-list (- arglength (length arguments)) #f))])
          (map (lambda (arg val)
                 (cons arg
                       (if (eq? (gi-arg-direction arg) 'out)
                           (ctype->_gi-argument _pointer
                                                (gi-type-malloc (gi-arg-type arg)))
                           (arg val))))
               args
               vals)))

      (define-values (in-args out-args)
        (let ([inputs (filter-map (lambda (pair) (and (gi-arg-direction? (car pair) '(in inout))
                                                 (cdr pair))) args+values)]
              [outputs (filter-map (lambda (pair) (and (gi-arg-direction? (car pair) '(inout out))
                                                  (cdr pair))) args+values)])
          (values (if method?
                      (cons (ctype->_gi-argument _pointer (car arguments)) inputs)
                      inputs)
                  outputs)))

      (gi-function-invoke fn in-args out-args))))

(define (gi-function-inbound-args fn)
  (filter (lambda (arg)
            (memq (gi-arg-direction arg) '(in inout)))
          (gi-callable-args fn)))

(define (gi-function-outbound-args fn)
  (filter (lambda (arg)
            (memq (gi-arg-direction arg) '(out inout)))
          (gi-callable-args fn)))

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
  #:c-id g_constant_info_get_type)

(define-gir gi-constant-value (_fun [const : _gi-base-info]
                                    [r : (_ptr o _gi-argument)]
                                    -> (size : _int)
                                    -> (let ([type (gi-constant-type const)])
                                         (type r)))
  #:c-id g_constant_info_get_value)

(define (describe-gi-constant constant)
  (gi-base-name constant))


;;; Registered Types
(struct gi-registered-type gi-base ())

(define-gir gi-registered-type-name (_fun _gi-base-info -> _symbol)
  #:c-id g_registered_type_info_get_type_name)

(define-gir gi-registered-type-gtype (_fun _gi-base-info -> _gtype)
  #:c-id g_registered_type_info_get_g_type)

(define (gi-registered-type-methods registered)
  (cond
    [(gi-object? registered) (gi-object-methods registered)]
    [(gi-struct? registered) (gi-struct-methods registered)]
    [else (error "This type does not implement methods")]))

(define (gi-registered-type-fields registered)
  (cond
    [(gi-object? registered) (gi-object-fields registered)]
    [(gi-struct? registered) (gi-struct-fields registered)]
    [else (error "This type does not implement fields")]))

(define (gi-registered-type-field/c reg)
  (apply symbols (map gi-base-name
                      (gi-registered-type-fields reg))))

(define (gi-registered-type-find-field registered field-name)
  (let ([fields (gi-registered-type-fields registered)])
    (or (findf (lambda (f) (equal? field-name
                              (gi-base-name f)))
               fields)
        (raise-argument-error 'gi-registered-type-find-field
                              (format "~.v" (gi-registered-type-field/c registered))
                              field-name))))

(struct gtype-instance (type pointer)
  #:property prop:cpointer 1)

(define (gtype-instance-gtype gtype)
  (gi-registered-type-gtype (gtype-instance-type gtype)))

(define (gtype-instance-type-name gtype)
  (gi-registered-type-name (gtype-instance-type gtype)))

(define (gtype-instance-name gtype)
  (gi-base-name (gtype-instance-type gtype)))

(define (is-a? instance type)
  (and (gi-registered-type? type)
       (gtype-instance? instance)
       (gi-base=? (gtype-instance-type instance) type)))

(define (is-a?/c type)
  (flat-named-contract `(is-a? ,(gi-registered-type-name type))
                       (curryr is-a? type)))

(define (gi-registered-type->ctype registered)
  (let* ([name (gi-base-sym registered)])
    (_cpointer/null name _pointer
                    values
                    (lambda (ptr)
                      (and ptr
                          (gtype-instance registered ptr))))))

;;; Structs
(struct gi-struct gi-registered-type ()
  #:property prop:procedure
  (lambda (structure method-name . arguments)
    (let ([method (gi-struct-find-method structure method-name)])
      (if method
          (apply method arguments)
          (error "o no method not found")))))

(struct gstruct gtype-instance ()
  #:property prop:procedure
  (lambda (instance method-name . arguments)
    (let ([base (gtype-instance-type instance)])
      (apply base method-name (cons instance arguments)))))

(define (_gi-struct structure)
  (let ([name (gi-base-sym structure)])
    (_cpointer/null name _pointer
                    values
                    (lambda (ptr)
                      (and ptr
                           (gstruct structure ptr))))))

(define (gstruct-cast pointer structure)
  (cast pointer _pointer (_gi-struct structure)))

(define-gir gi-struct-alignment (_fun _gi-base-info -> _size)
  #:c-id g_struct_info_get_alignment)

(define-gir gi-struct-size (_fun _gi-base-info -> _size)
  #:c-id g_struct_info_get_size)

(define-gir gi-struct-n-fields (_fun _gi-base-info -> _int)
  #:c-id g_struct_info_get_n_fields)

(define-gir gi-struct-field (_fun _gi-base-info _int
                                  -> _gi-base-info)
  #:c-id g_struct_info_get_field)

(struct gi-field gi-base ()
  #:property prop:procedure
  (lambda (field value)
    (gi-type->_gi-argument (gi-field-type field) value)))

(define (gi-struct-fields structure)
  (gi-build-list structure gi-struct-n-fields gi-struct-field))

(define-gir gi-field-type (_fun _gi-base-info
                                -> _gi-base-info)
  #:c-id g_field_info_get_type)

(define-gir gi-field-ref (_fun [field : _gi-base-info] _pointer
                               [r : (_ptr o _gi-argument)]
                               -> (success? : _bool)
                               -> (and success?
                                       (let ([type (gi-field-type field)])
                                         (type r))))
  #:c-id g_field_info_get_field)

(define-gir gi-field-set! (_fun [field : _gi-base-info] _pointer
                                [arg : _?]
                                [r : (_ptr i _gi-argument) = (field arg)]
                                -> (success? : _bool)
                                -> (if success?
                                       (void)
                                       (raise-arguments-error 'gi-field-set! "failed to set field"
                                                              "field" (gi-base-name field)
                                                              "arg" arg)))
  #:c-id g_field_info_set_field)

(define (describe-gi-field field)
  (format "~a ~a"
          (describe-gi-type (gi-field-type field))
          (gi-base-name field)))

(define-gir gi-struct-n-methods (_fun _gi-base-info -> _int)
  #:c-id g_struct_info_get_n_methods)

(define-gir gi-struct-method (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_struct_info_get_method)

(define (gi-struct-methods structure)
  (gi-build-list structure gi-struct-n-methods gi-struct-method))

(define (gi-struct-known-method? structure)
  (apply one-of/c (map gi-base-name (gi-struct-methods structure))))

(define-gir gi-struct-find-method (_fun (structure : _gi-base-info) (method : _symbol)
                                        -> (res : _gi-base-info)
                                        -> (or res
                                               (raise-argument-error 'gi-struct-find-method
                                                                     (format "~.v" (gi-struct-known-method? structure))
                                                                     method)))
  #:c-id g_struct_info_find_method)

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
  #:c-id g_enum_info_get_value)

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
  gi-base-sym)

(define-gir gi-value-get (_fun _gi-base-info
                               -> _int64)
  #:c-id g_value_info_get_value)

(define (gi-enum-values enum)
  (gi-build-list enum gi-enum-n-values gi-enum-value))

(define (gi-enum->list enum)
  (map (lambda (val) (val))
       (gi-enum-values enum)))

(define (gi-enum->hash enum)
  (make-hash (map (lambda (val) (cons (val) (gi-value-get val)))
                  (gi-enum-values enum))))

(define-gir gi-enum-n-methods (_fun _gi-base-info -> _int)
  #:c-id g_enum_info_get_n_methods)

(define-gir gi-enum-method (_fun _gi-base-info _int
                                 -> _gi-base-info)
  #:c-id g_enum_info_get_method)

(define (gi-enum-methods enum)
  (gi-build-list enum gi-enum-n-methods gi-enum-value))

(define (gi-enum->ctype enum)
  (let ([symbols (apply append
                        (for/list ([(key val) (in-hash (gi-enum->hash enum))])
                          (list key '= val)))])
    (case (gi-base-type enum)
      ['GI_INFO_TYPE_FLAGS (_bitmask symbols
                                     (gi-enum-storage-type enum))]
      [else (_enum symbols
                   (gi-enum-storage-type enum))])))


;;; Objects
(struct gi-object gi-registered-type ()
  #:property prop:procedure
  (lambda (object method-name . arguments)
    (define method (gi-object-lookup-method object method-name))
    (if method
        (call-with-values (thunk (apply method arguments))
                          (case-lambda
                            [(invocation)
                             (if (and (gobject? invocation)
                                      (memq 'constructor? (gi-function-flags method)))
                                 (let ([base (gtype-instance-type invocation)])
                                   (cast invocation
                                         (_gi-object base)
                                         (_gi-object object)))
                                 invocation)]
                            [rest (apply values rest)]))
        (error "o no method not found"))))

(struct gobject gtype-instance ())

(define (gi-object-lookup-method obj method-name)
  (let ([method (gi-object-find-method obj method-name)]
        [parent (gi-object-parent obj)])
    (or method
        (and parent
             (gi-object-lookup-method parent method-name)))))

(define (method-names object)
  (let ([base (gtype-instance-type object)])
    (map gi-base-sym (gi-registered-type-methods base))))

(define (describe-method instance method-name)
  (let* ([base (gtype-instance-type instance)]
         [method (gi-object-lookup-method base method-name)])
    (and method
         (describe-gi-function method))))

(define (gobject-has-field? obj field-name)
  (let* ([base (gtype-instance-type obj)]
         [fields (map gi-base-sym (gi-registered-type-fields base))])
    (and (memq field-name fields)
         #t)))

(define (dynamic-send obj method-name . arguments)
  (let ([base (gtype-instance-type obj)]
        [ptr (gtype-instance-pointer obj)])
    (apply base method-name (cons ptr arguments))))

(define (dynamic-get-field field-name obj)
  (let* ([base (gtype-instance-type obj)]
         [ptr (gtype-instance-pointer obj)]
         [field (gi-registered-type-find-field base field-name)])
    (gi-field-ref field ptr)))

(define (dynamic-set-field! field-name obj v)
  (let* ([base (gtype-instance-type obj)]
         [ptr (gtype-instance-pointer obj)]
         [field (gi-registered-type-find-field base field-name)])
    (gi-field-set! field ptr v)))

(define-syntax (send stx)
  (syntax-parse stx
    [(_ obj method-id:id args:expr ...)
     #:declare obj (expr/c #'(or/c gobject? gstruct?)
                           #:name "receiver")
     (with-syntax ([method-name (string->symbol (string-replace
                                                 (symbol->string (syntax-e #'method-id))
                                                 "-" "_"))])
       #'(dynamic-send obj.c 'method-name args ...))]))

(define-syntax (responds-to? stx)
  (syntax-parse stx
    [(_ obj method-id:id args:expr ...)
     #:declare obj (expr/c #'(or/c gobject? gstruct?)
                           #:name "receiver")
     (with-syntax ([method-name (string->symbol (string-replace
                                                 (symbol->string (syntax-e #'method-id))
                                                 "-" "_"))])
       #'(and (gi-object-lookup-method (gtype-instance-type obj.c)
                                       'method-name)
              #t))]))

(define-syntax (get-field stx)
  (syntax-parse stx
    [(_ field-id:id obj)
     #:declare obj (expr/c #'(or/c gobject? gstruct?)
                           #:name "instance")
     (with-syntax ([field-name (string->symbol (string-replace
                                                 (symbol->string (syntax-e #'field-id))
                                                 "-" "_"))])
       #'(dynamic-get-field 'field-name obj.c))]))

(define-syntax (set-field! stx)
  (syntax-parse stx
    [(_ field-id:id obj val:expr)
     #:declare obj (expr/c #'(or/c gobject? gstruct?)
                           #:name "instance")
     (with-syntax ([field-name (string->symbol (string-replace
                                                 (symbol->string (syntax-e #'field-id))
                                                 "-" "_"))])
       #'(dynamic-set-field! 'field-name obj.c val))]))

(define-syntax (field-bound? stx)
  (syntax-parse stx
    [(_ field-id:id obj)
     #:declare obj (expr/c #'gobject?
                           #:name "instance")
     #'(gobject-has-field? obj.c 'field-id)]))

(define (_gi-object obj)
  (let ([name (gi-base-sym obj)]
        [parent (gi-object-parent obj)])
    (_cpointer/null name (if parent (_gi-object parent) _pointer)
                    values
                    (lambda (ptr)
                      (and ptr
                           (gobject obj (if (gtype-instance? ptr)
                                            (gtype-instance-pointer ptr)
                                            ptr)))))))

(define-gobject gobject-unref! (_fun _pointer -> _void)
  #:wrap (deallocator)
  #:c-id g_object_unref)

(define-gobject gobject-ref-sink (_fun _pointer -> _pointer)
  #:wrap (allocator gobject-unref!)
  #:c-id g_object_ref_sink)

(define (gobject-cast pointer obj)
  (cast pointer _pointer (_gi-object obj)))

(define-gobject gobject-get (_fun _pointer _string (ctype : _?)
                                  [ret : (_ptr o ctype)] (_pointer = #f)
                                  -> _void
                                  -> ret)
  #:c-id g_object_get)

(define (gobject-set! gobject propname value [ctype #f])
  (let* ([_value (cond
                   [(ctype? ctype) ctype]
                   [((listof symbol?) ctype) (_enum ctype)]
                   [(gobject? value) (_gi-object (gtype-instance-type value))]
                   [(gstruct? value) (_gi-struct (gtype-instance-type value))]
                   [(boolean? value) _bool]
                   [(string? value) _string]
                   [(exact-integer? value) _int]
                   [(flonum? value) _double]
                   [else _pointer])]
         [setter (get-ffi-obj "g_object_set"
                              libgobject
                              (_fun _pointer _string _value (_pointer = #f)
                                    -> _void))])
    (setter gobject propname value)))

(define (gobject-with-properties instance properties)
  (hash-for-each properties
                 (lambda (key val) (gobject-set! instance (symbol->string key) val)))
  instance)

(define-gir gi-object-parent (_fun _gi-base-info -> _gi-base-info)
  #:c-id g_object_info_get_parent)

(define (gi-object-ancestors obj)
  (let ([parent (gi-object-parent obj)])
    (if parent
        (cons parent (gi-object-ancestors parent))
        null)))

(define-gir gi-object-class (_fun _gi-base-info -> _gi-base-info)
  #:c-id g_object_info_get_class_struct)

(define-gir gi-object-n-constants (_fun _gi-base-info -> _int)
  #:c-id g_object_info_get_n_constants)

(define-gir gi-object-constant (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_object_info_get_constant)

(define (gi-object-constants obj)
  (gi-build-list obj gi-object-n-constants gi-object-constant))

(define-gir gi-object-n-fields (_fun _gi-base-info -> _int)
  #:c-id g_object_info_get_n_fields)

(define-gir gi-object-field (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_object_info_get_field)

(define (gi-object-fields obj)
  (gi-build-list obj gi-object-n-fields gi-object-field))

(define-gir gi-object-n-interfaces (_fun _gi-base-info -> _int)
  #:c-id g_object_info_get_n_interfaces)

(define-gir gi-object-interface (_fun _gi-base-info _int
                                          -> _gi-base-info)
  #:c-id g_object_info_get_interface)

(define (gi-object-interfaces obj)
  (gi-build-list obj gi-object-n-interfaces gi-object-interface))

(define-gir gi-object-n-methods (_fun _gi-base-info -> _int)
  #:c-id g_object_info_get_n_methods)

(define-gir gi-object-method (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_object_info_get_method)

(define (gi-object-methods obj)
  (gi-build-list obj gi-object-n-methods gi-object-method))

(define (gi-object-method/c obj)
  (apply symbols (map gi-base-name (gi-object-methods obj))))

(define-gir gi-object-find-method (_fun (obj : _gi-base-info) (method : _symbol)
                                        -> _gi-base-info)
  #:c-id g_object_info_find_method)

(define-gir gi-object-n-properties (_fun _gi-base-info -> _int)
  #:c-id g_object_info_get_n_properties)

(define-gir gi-object-property (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_object_info_get_property)

(define (gi-object-properties obj)
  (gi-build-list obj gi-object-n-properties gi-object-property))

(struct gi-property gi-base ())

(define-gir gi-object-n-signals (_fun _gi-base-info -> _int)
  #:c-id g_object_info_get_n_signals)

(define-gir gi-object-signal (_fun _gi-base-info _int
                                   -> _gi-base-info)
  #:c-id g_object_info_get_signal)

(define (gi-object-signals obj)
  (gi-build-list obj gi-object-n-signals gi-object-signal))

(define-gir gi-object-find-signal (_fun _gi-base-info _symbol
                                        -> _gi-base-info)
  #:c-id g_object_info_find_signal)

(struct gi-signal gi-callable ())

(define (gi-signal->ctype obj signal
                          [_user-data _pointer])
  (let ([args (gi-callable-args signal)]
        [returns (gi-callable-returns signal)]
        [worker (make-signal-worker (gi-base-name signal))])
    (_cprocedure #:async-apply (lambda (thunk)
                                 (thread-send worker thunk))
                 (append (list (_gi-object obj))
                         (map (compose1 gi-type->ctype gi-arg-type) args)
                         (list _user-data))
                 (gi-type->ctype returns))))

(define (make-signal-worker signal-name)
  (thread (thunk
            (let loop ()
              (let ([callback (thread-receive)])
                (callback)
                (loop))))))

(define _gsignal-flags (_bitmask '(run-first
                                   run-last
                                   run-cleanup
                                   no-recurse
                                   detailed
                                   action
                                   no-hooks
                                   must-collect
                                   deprecated)))

(define-cstruct _gsignal-query ([id _uint]
                                [name _string]
                                [itype _gtype]
                                [flags _gsignal-flags]
                                [return-type _gtype]
                                [n-params _uint]
                                [param-types _bytes]))

(define-gobject signal-query (_fun _int [query : (_ptr o _gsignal-query)]
                                   -> _void
                                   -> query)
  #:c-id g_signal_query)

(define-gobject signal-lookup (_fun _symbol _gtype -> _int)
  #:c-id g_signal_lookup)

(define-gobject signal-name (_fun _int -> _symbol)
  #:c-id g_signal_name)

(define (connect object signal-name handler
                 #:data [data #f]
                 #:cast [_user-data #f])
  (let* ([base (gtype-instance-type object)]
         [ptr (gtype-instance-pointer object)]
         [signal (or (gi-object-find-signal base signal-name)
                     (error "signal not found"))]
         [_signal (gi-signal->ctype base signal
                                    (cond
                                      [(ctype? _user-data) _user-data]
                                      [(gi-object? _user-data)
                                       (_gi-object _user-data)]
                                      [(gobject? data)
                                       (_gi-object (gtype-instance-type data))]
                                      [else _pointer]))])
    (define signal-connect-data
      (get-ffi-obj "g_signal_connect_data" libgobject
                   (_fun _pointer _string _signal _pointer
                         (_pointer = #f) (_bitmask '(after swapped))
                         -> _ulong)))
    (signal-connect-data ptr
                         (symbol->string signal-name)
                         handler
                         data
                         null)))

;;; Repositories
(struct gi-repository (namespace version info-hash)
  #:property prop:procedure
  (case-lambda
    [(repo) (gi-repository-info-hash repo)]
    [(repo name) (gi-repository-find-name repo name)]))

(define-gir gir-require (_fun (_pointer = #f) (namespace : _symbol) (version : _string)
                              (_int = 0) ; Lazy mode
                              (err : (_ptr io _gerror-pointer/null) = #f)
                              -> (r : _pointer)
                              -> (if r
                                     (gi-repository namespace
                                                    version
                                                    (for/hash ([info (gir-infos namespace)])
                                                      (values (gi-base-name info)
                                                              info)))
                                     (error (gerror-message err))))
  #:c-id g_irepository_require)

(define-gir gir-n-infos (_fun (_pointer = #f) _symbol -> _int)
  #:c-id g_irepository_get_n_infos)

(define-gir gir-info (_fun (_pointer = #f) _symbol _int -> _gi-base-info)
  #:c-id g_irepository_get_info)

(define (gir-infos namespace)
  (gi-build-list namespace gir-n-infos gir-info))

(define-gir gir-find-by-name (_fun (_pointer = #f) _symbol _symbol -> _gi-base-info)
  #:c-id g_irepository_find_by_name)

(define-gir gir-get-shared-library (_fun (_pointer = #f) _symbol -> _path)
  #:c-id g_irepository_get_shared_library)

(define (gi-repository-find-name repo name)
  (define namespace (gi-repository-namespace repo))
  (or (gir-find-by-name namespace name)
      (raise-argument-error 'gi-repository-find-name
                            (format "(gir-member/c ~v)" namespace)
                            name)))

(define-gir gir-find-by-gtype (_fun (_pointer = #f) _gtype -> _gi-base-info)
  #:c-id g_irepository_find_by_gtype)

(define (gi-repository-find-gtype repo gtype)
  (gir-find-by-gtype (gi-repository-namespace repo) gtype))

(define (gi-repository->ffi-lib repo)
  (let ([libpath (gir-get-shared-library (gi-repository-namespace repo))])
    (ffi-lib libpath)))

(define (gi-repository-member/c repo)
  (gir-member/c (gi-repository-namespace repo)))

(define (gir-member/c namespace)
  (apply symbols (map gi-base-name (gir-infos namespace))))

(define (introspection namespace [version #f])
  (gir-require namespace version))

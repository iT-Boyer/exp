#lang racket/base
(require rackunit
         racket/list
         racket/match
         racket/stxparam
         (for-syntax racket/base
                     racket/syntax
                     racket/list
                     syntax/parse))

(define-syntax-parameter stack
  (λ (stx) (raise-syntax-error 'stack "Illegal outside rorth" stx)))

(struct stack-op (f)
        #:property prop:procedure
        (λ (so . args)
          ;; xxx slow
          (apply values (rorth/stack (reverse args) so))))

(define-syntax (define/raw-rorth stx)
  (syntax-parse stx
    [(_ name:id . body)
     #'(define name
         (stack-op
          (λ (this-stack)
            (syntax-parameterize ([stack (make-rename-transformer #'this-stack)])
              . body))))]))

(define-syntax (define/rorth stx)
  (syntax-parse stx
    [(_ name:id body ...)
     #'(define/raw-rorth name
         (rorth/stack stack body ...))]))

(begin-for-syntax
  (define (generate-n-temporaries stx)
    (generate-temporaries (build-list (syntax->datum stx) (λ (i) stx)))))

(define-syntax (define-rorth stx)
  (syntax-parse stx
    [(_ new-name:id (input:nat -- output:nat) name:id)
     (with-syntax*
      ([(in_0 ...) (generate-n-temporaries #'input)]
       [(in_n ...) (reverse (syntax->list #'(in_0 ...)))]
       [(out_0 ...) (generate-n-temporaries #'output)]
       [(out_n ...) (reverse (syntax->list #'(out_0 ...)))])
      #'(define/raw-rorth new-name
          (match-define (list* in_n ... left-over) stack)
          (define-values (out_0 ...) (name in_0 ...))
          (list* out_n ... left-over)))]))

(define-syntax-rule (rorth . body)
  (rorth/stack empty . body))

(define (maybe-apply-stack-op e stk)
  (if (stack-op? e)
    ((stack-op-f e) stk)
    (list* e stk)))

(define-syntax (rorth/stack stx)
  (syntax-parse stx
    [(_ stk:expr)
     #'stk]
    [(_ stk:expr e:expr)
     #'(maybe-apply-stack-op e stk)]
    [(_ stk:expr f:expr m:expr ...)
     #'(rorth/stack (rorth/stack stk f) m ...)]))

(define-syntax-rule (check-rorth (r ...) (a ...))
  (check-equal? (reverse (rorth r ...))
                (list a ...)))

(define/raw-rorth :dup
  (match-define (list* top rest) stack)
  (list* top top rest))
(define/raw-rorth :drop
  (match-define (list* top rest) stack)
  rest)
(define/raw-rorth :swap
  (match-define (list* a b rest) stack)
  (list* b a rest))
(define/raw-rorth :rot
  (match-define (list* a b c rest) stack)
  (list* c a b rest))
(define/raw-rorth :over
  (match-define (list* a b rest) stack)
  (list* b a b rest))
(define/raw-rorth :tuck
  (match-define (list* a b rest) stack)
  (list* a b a rest))
(define/raw-rorth :pick
  (match-define (list* i rest) stack)
  (list* (list-ref rest i) rest))

(define-rorth :+ (2 -- 1) +)
(define-rorth :- (2 -- 1) -)
(define-rorth :* (2 -- 1) *)

(provide define/rorth
         define-rorth
         rorth
         check-rorth
         :pick :tuck :over :rot :drop :dup :+ :- :* :swap)

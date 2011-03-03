#lang racket
(require tests/eli-tester
         "foo.rkt")

; point-2D object and its constructor
(define-method* get-x get-y test-kw set-x set-y of-class)
(define (point-2D x y)
  (object (object%)
          (define (get-x) x)
          (define (get-y) y)
          (define (test-kw #:something z)
            (+ x y z))
          (define (set-x new-x)
            (update [get-x new-x]))
          (define (set-y new-y)
            (update [get-y new-y]))
          (define (class)
            "point-2D")
          (define (of-class)
            (class self))))

(define (print-x-y obj)
  (list (class obj)
        (get-x obj)
        (get-y obj)))

(define p (point-2D 5 6))
(define p1 (point-2D 5 6))

; pm is the object 'p' after the "mutation"
; Note that closures 'pm' and 'p' _share_ all the common state,
; including their identity
(define pm (set-x p 10))

; Illustrating inheritance and polymorphism
; A derived "object" inherits the message-map of its parent, and
; adds its own handlers at the top. Because subclass' handlers will
; be encountered first when a handler for a selector is being
; searched, the subclass is able to override the behavior of its
; superclass.

(define-method* get-z set-z)
(define (point-3D x y z)
  (object (point-2D x y)
          (define (get-z) z)
          (define (set-z new-z)
            (update [get-z new-z]))
          (define (class)
            "point-3D")))

(define q (point-3D 1 2 3))

(test
 (of-class p1) => "point-2D"
 (get-x p) => 5
 (get-x p1) => 5
 (test-kw p #:something 7) => 18
 
 (print-x-y p) => (list "point-2D" 5 6)
 ; p and p1 happen at this point to be in the same state
 (equal? (print-x-y p) (print-x-y p1))
 
 ; but p and p1 are different, non-identical objects
 (eq? (identity p) (identity p1)) => #f

 (print-x-y pm) => (list "point-2D" 10 6)
 
 ; States differ, identities are the same
 (equal? (print-x-y p) (print-x-y pm)) => #f
 (eq? (identity p) (identity pm))

 ; Although print-x-y was defined for objects of type point-2D,
 ; it accepts point-3D objects as well. Note however that the head
 ; of print-x-y's result spells "point-3D". This is because a point-3D
 ; object overrides the message 'class of its parent class
 (print-x-y q) => (list "point-3D" 1 2)
 (get-z q) => 3
 
 ; Demonstrating the use of inherited methods....
 (let ([obj (set-z (set-x q 11) 12)])
   (append (print-x-y obj) (list (get-z obj))))
 => (list "point-3D" 11 2 12) 
 
 (of-class q) => "point-3D" ; notice polymorphism!!!
 ; The of-class method is implemented in point-2D yet the result is
 ; "point-3D". This is because the 'of-class method sends the message
 ; 'class to itself. The latter handler is over-ridden in a
 ; class point-3D to return its own title, "point-3D".
 
 (object 1) =error> "the parent argument")
;;; -------- pluck
;;;
;;; The Karplus-Strong algorithm as extended by David Jaffe and Julius Smith -- see 
;;;  Jaffe and Smith, "Extensions of the Karplus-Strong Plucked-String Algorithm"
;;;  CMJ vol 7 no 2 Summer 1983, reprinted in "The Music Machine".
;;;  translated from CLM's pluck.ins


(definstrument (pluck start dur freq amp (weighting .5) (lossfact .9))
  "(pluck start dur freq amp weighting lossfact) implements the Jaffe-Smith plucked string physical model. 
'weighting' is the ratio of the once-delayed to the twice-delayed samples.  It defaults to .5=shortest decay. 
Anything other than .5 = longer decay.  Must be between 0 and less than 1.0. 
'lossfact' can be used to shorten decays.  Most useful values are between .8 and 1.0. (with-sound () (pluck 0 1 330 .3 .995 .995))"

  (define (getOptimumC S o p)
    (let* ((pa (* (/ 1.0 o) (atan (* S (sin o)) (+ (- 1.0 S) (* S (cos o))))))
	   (tmpInt (floor (- p pa)))
	   (pc (- p pa tmpInt)))
      (if (< pc .1)
	  (do ()
	      ((>= pc .1))
	    (set! tmpInt (- tmpInt 1))
	    (set! pc (+ pc 1.0))))
      (list tmpInt (/ (- (sin o) (sin (* o pc))) (sin (+ o (* o pc)))))))
  
  (define (tuneIt f s1)
    (let ((p (/ *clm-srate* f))	;period as float
	  (s (if (= s1 0.0) 0.5 s1))
	  (o (hz->radians f)))
      (let ((vals (getOptimumC s o p))
	    (vals1 (getOptimumC (- 1.0 s) o p)))
	(if (and (not (= s .5))
		 (< (abs (cadr vals)) (abs (cadr vals1))))
	    (list (- 1.0 s) (cadr vals) (car vals))
	    (list s (cadr vals1) (car vals1))))))
  
  (let ((vals (tuneIt freq weighting)))
    (let ((wt0 (car vals))
	  (c (cadr vals))
	  (dlen (caddr vals))
	  (beg (seconds->samples start))
	  (end (seconds->samples (+ start dur)))
	  (lf (if (= lossfact 0.0) 1.0 (min 1.0 lossfact))))

      (let ((wt (if (= wt0 0.0) 0.5 (min 1.0 wt0)))
	    (tab (make-vector dlen 0.0)))

	;; get initial waveform in "tab" -- here we can introduce 0's to simulate different pick
	;; positions, and so on -- see the CMJ article for numerous extensions.  The normal case
	;; is to load it with white noise (between -1 and 1).
	(let ((allp (make-one-zero (* lf (- 1.0 wt)) (* lf wt)))
	      (feedb (make-one-zero c 1.0)) ;or (feedb (make-one-zero 1.0 c))
	      (ctr 0)
	      (c1 (- 1.0 c)))
	  
	  (do ((i 0 (+ i 1)))
	      ((= i dlen))
	    (set! (tab i) (mus-random 1.0)))
	  (do ((i beg (+ i 1)))
	      ((= i end))
	    (let ((val (tab ctr)))	;current output value
	      (set! (tab ctr) (* c1 (one-zero feedb (one-zero allp val))))
	      (set! ctr (+ ctr 1))
	      (if (>= ctr dlen) (set! ctr 0))
	      (outa i (* amp val)))))))))
(provide 'snd-jcrev.scm)

(if (provided? 'snd)
    (if (not (provided? 'snd-ws.scm)) (load "ws.scm"))
    (if (not (provided? 'sndlib-ws.scm)) (load "sndlib-ws.scm")))


(definstrument (jc-reverb (low-pass #f) (volume 1.0) (amp-env #f))
  "(jc-reverb (low-pass #f) (volume 1.0) (amp-env #f)) -- Chowning reverb"
  (let ((allpass1 (make-all-pass -0.700 0.700 1051))
	(allpass2 (make-all-pass -0.700 0.700  337))
	(allpass3 (make-all-pass -0.700 0.700  113))
	(comb1 (make-comb 0.742 4799))
	(comb2 (make-comb 0.733 4999))
	(comb3 (make-comb 0.715 5399))
	(comb4 (make-comb 0.697 5801))
	(decay-dur *clm-srate*)
	(chns (channels *output*))
	(file-dur (frames *reverb*)))

    (let ((len (floor (+ decay-dur file-dur)))
	  (filts (if (= chns 1) 
		     (vector (make-delay (seconds->samples .013)))
		     (vector (make-delay (seconds->samples .013))
			     (make-delay (seconds->samples .011)))))
	  (combs (make-comb-bank (vector comb1 comb2 comb3 comb4)))
	  (allpasses (make-all-pass-bank (vector allpass1 allpass2 allpass3))))

      (if (or amp-env low-pass)
	  (let ((flt (if low-pass (make-fir-filter 3 (float-vector 0.25 0.5 0.25)) #f))
		(envA (make-env :envelope (or amp-env '(0 1 1 1)) :scaler volume :duration (/ len *clm-srate*))))
	    (if low-pass
		(do ((i 0 (+ i 1)))
		    ((= i len))
		  (out-bank filts i (* (env envA) (fir-filter flt (comb-bank combs (all-pass-bank allpasses (ina i *reverb*)))))))
		(do ((i 0 (+ i 1)))
		    ((= i len))
		  (out-bank filts i (* (env envA) (comb-bank combs (all-pass-bank allpasses (ina i *reverb*))))))))
	  (do ((i 0 (+ i 1)))
	      ((= i len))
	    (out-bank filts i (* volume (comb-bank combs (all-pass-bank allpasses (ina i *reverb*))))))))))
  
;;; (with-sound (:reverb jc-reverb) (fm-violin 0 .1 440 .1 :reverb-amount .3))
;;; (with-sound (:reverb jc-reverb) (outa 0 .1) (outa 0 .5 *reverb*))
;;; (with-sound (:reverb jc-reverb :reverb-data '((:low-pass #t))) (outa 0 .1) (outa 0 .5 *reverb*))
;;; (with-sound (:statistics #t :reverb jc-reverb :reverb-data '((:low-pass #t))) (outa 0 .1) (outa 100000 .1) (outa 0 .5 *reverb*) (outa 100000 .5 *reverb*))

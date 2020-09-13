(definstrument (drone startime dur frequency amp ampfun synth ampat ampdc amtrev deg dis rvibamt rvibfreq)
  (let ((beg (seconds->samples startime))
	 (end (seconds->samples (+ startime dur)))
	 (waveform (partials->wave synth))
	 (amplitude (* amp .25))
	 (freq (hz->radians frequency)))
    (let ((s (make-table-lookup :frequency frequency :wave waveform))
	  (amp-env (make-env (stretch-envelope ampfun 25 (* 100 (/ ampat dur)) 75 (- 100 (* 100 (/ ampdc dur))))
			     :scaler amplitude :duration dur))
	  (ran-vib (make-rand :frequency rvibfreq 
			      :amplitude (* rvibamt freq)))
	  (loc (make-locsig deg dis amtrev)))
      (do ((i beg (+ i 1)))
	  ((= i end))
	(locsig loc i (* (env amp-env) (table-lookup s (rand ran-vib))))))))

(definstrument (canter beg dur pitch amp-1 deg dis pcrev ampfun ranfun skewfun
		       skewpc ranpc ranfreq indexfun atdr dcdr
		       ampfun1 indfun1 fmtfun1
		       ampfun2 indfun2 fmtfun2
		       ampfun3 indfun3 fmtfun3
		       ampfun4 indfun4 fmtfun4)
  (let ((amp (* amp-1 .25))		;pvc's amplitudes in bag.clm are very high (overflows)
	(rangetop 910.0)
	(rangebot 400.0))
    (let ((k (floor (* 100 (log (/ pitch rangebot) (/ rangetop rangebot)))))
	  (atpt (* 100 (/ atdr dur)))
	  (dcpt (- 100 (* 100 (/ dcdr dur)))))
      (let ((lfmt1 (envelope-interp k fmtfun1))
	    (lfmt2 (envelope-interp k fmtfun2))
	    (lfmt3 (envelope-interp k fmtfun3))
	    (lfmt4 (envelope-interp k fmtfun4))
	    (dev11 (hz->radians (* (envelope-interp k indfun1) pitch)))
	    (dev12 (hz->radians (* (envelope-interp k indfun2) pitch)))
	    (dev13 (hz->radians (* (envelope-interp k indfun3) pitch)))
	    (dev14 (hz->radians (* (envelope-interp k indfun4) pitch))))
	(let ((start (seconds->samples beg))
	      (end (seconds->samples (+ beg dur)))
	      (dev01 (* dev11 .5))
	      (dev02 (* dev12 .5))
	      (dev03 (* dev13 .5))
	      (dev04 (* dev14 .5))
	      (harm1 (floor (+ .5 (/ lfmt1 pitch))))
	      (harm2 (floor (+ .5 (/ lfmt2 pitch))))
	      (harm3 (floor (+ .5 (/ lfmt3 pitch))))
	      (harm4 (floor (+ .5 (/ lfmt4 pitch)))))
	  (let ((lamp1 (* (envelope-interp k ampfun1) amp (- 1 (abs (- harm1 (/ lfmt1 pitch))))))
		(lamp2 (* (envelope-interp k ampfun2) amp (- 1 (abs (- harm2 (/ lfmt2 pitch))))))
		(lamp3 (* (envelope-interp k ampfun3) amp (- 1 (abs (- harm3 (/ lfmt3 pitch))))))
		(lamp4 (* (envelope-interp k ampfun4) amp (- 1 (abs (- harm4 (/ lfmt4 pitch))))))
		(tidx-stretched (stretch-envelope indexfun 25 atpt 75 dcpt)))
	    (let ((tampfun (make-env (stretch-envelope ampfun 25 atpt 75 dcpt) :duration dur))
		  (tskwfun (make-env (stretch-envelope skewfun 25 atpt 75 dcpt) :scaler (hz->radians (* pitch skewpc)) :duration dur))
		  (tranfun (make-env (stretch-envelope ranfun 25 atpt 75 dcpt) :duration dur))
		  (d1env (make-env tidx-stretched :offset dev01 :scaler dev11 :duration dur))
		  (d2env (make-env tidx-stretched :offset dev02 :scaler dev12 :duration dur))
		  (d3env (make-env tidx-stretched :offset dev03 :scaler dev13 :duration dur))
		  (d4env (make-env tidx-stretched :offset dev04 :scaler dev14 :duration dur))
		  (modgen (make-oscil pitch))
		  (ranvib (make-rand :frequency ranfreq :amplitude (hz->radians (* ranpc pitch))))
		  (loc (make-locsig deg dis pcrev))
		  (gen1 (make-oscil (* pitch harm1)))
		  (gen2 (make-oscil (* pitch harm2)))
		  (gen3 (make-oscil (* pitch harm3)))
		  (gen4 (make-oscil (* pitch harm4))))
	      (do ((i start (+ i 1)))
		  ((= i end))
		(let* ((frqval (+ (env tskwfun) (* (env tranfun) (rand ranvib))))
		       (modval (oscil modgen frqval)))
		  (locsig loc i (* (env tampfun)
				   (+ (* lamp1 (oscil gen1 (* (+ (* (env d1env) modval) frqval) harm1)))
				      (* lamp2 (oscil gen2 (* (+ (* (env d2env) modval) frqval) harm2)))
				      (* lamp3 (oscil gen3 (* (+ (* (env d3env) modval) frqval) harm3)))
				      (* lamp4 (oscil gen4 (* (+ (* (env d4env) modval) frqval) harm4)))))))))))))))










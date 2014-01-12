-- This code was automatically generated by lhs2tex --code, from the file 
-- HSoM/SigFuns.lhs.  (See HSoM/MakeCode.bat.)

{-# LANGUAGE Arrows #-}

module Euterpea.Music.Signal.SigFuns where

import Euterpea
import Control.Arrow ((>>>),(<<<),arr)
type AudSF a b  = SigFun AudRate a b
type CtrSF a b  = SigFun CtrRate a b
s1 :: Clock c => SigFun c () Double
s1 = proc () -> do
       s <- oscFixed 440 -< ()
       outA -< s
tab1 :: Table
tab1 = tableSinesN 4096 [1]
s2 :: Clock c => SigFun c () Double
s2 = proc () -> do
       osc tab1 0 -< 440
tab2 = tableSinesN 4096 [1.0,0.5,0.33]
s3 :: Clock c => SigFun c () Double
s3 = proc () -> do
       osc tab2 0 -< 440
s4 :: Clock c => SigFun c () Double
s4 = proc () -> do
       f0  <- oscFixed 440   -< ()
       f1  <- oscFixed 880   -< ()
       f2  <- oscFixed 1320  -< ()
       outA -< (f0 + 0.5*f1 + 0.33*f2) / 1.83
vibrato ::   Clock c =>
             Double -> Double -> SigFun c Double Double
vibrato vfrq dep = proc afrq -> do
  vib  <- osc tab1  0 -< vfrq
  aud  <- osc tab2  0 -< afrq + vib * dep
  outA -< aud
s5 :: AudSF () Double
s5 = constA 1000 >>> vibrato 5 20
simpleClip :: Clock c => SigFun c Double Double
simpleClip = arr f where
  f x = if abs x <= 1.0 then x else signum x
time :: Clock c => SigFun c () Double
time = integral <<< constA 1
simpleInstr :: InstrumentName
simpleInstr = Custom "Simple Instrument"
myInstr :: Instr (AudSF () Double)
  --Dur -> AbsPitch -> Volume -> [Double] -> (AudSF () Double)|
myInstr dur ap vol [vfrq,dep] =
  proc () -> do
       vib  <- osc tab1  0 -< vfrq
       aud  <- osc tab2  0 -< apToHz ap + vib * dep
       outA -< aud
myInstrMap :: InstrMap (AudSF () Double)
myInstrMap = [(simpleInstr, myInstr)]
(dr, sf)  = renderSF mel myInstrMap
main     = outFile "simple.wav" dr sf
mel :: Music1
mel =  
  let  m = Euterpea.line [  na1 (c 4 en),   na1 (ef 4 en),  na1 (f 4 en), 
                     na2 (af 4 qn),  na1 (f 4 en),   na1 (af 4 en), 
                     na2 (bf 4 qn),  na1 (af 4 en),  na1 (bf 4 en),
                     na1 (c 5 en),   na1 (ef 5 en),  na1 (f 5 en),
                     na3 (af 5 wn) ]
       na1 (Prim (Note d p))  = Prim (Note d (p,[Params [0, 0]]))
       na2 (Prim (Note d p))  = Prim (Note d (p,[Params [5,10]]))
       na3 (Prim (Note d p))  = Prim (Note d (p,[Params [5,20]]))
  in instrument simpleInstr m

%-*- mode: Latex; abbrev-mode: true; auto-fill-function: do-auto-fill -*-

%include lhs2TeX.fmt
%include myFormat.fmt

\out{
\begin{code}
-- This code was automatically generated by lhs2tex --code, from the file 
-- HSoM/RandomMusic.lhs.  (See HSoM/MakeCode.bat.)

\end{code}
}

\chapter[Random Numbers ... and Markov Chains]
{Random Numbers, Probability Distributions, and Markov Chains}
\label{ch:random}

\begin{code}
module Euterpea.Examples.RandomMusic where

import Euterpea

import System.Random
import System.Random.Distributions
import qualified Data.MarkovChain as M
\end{code}

The use of randomness in composition can be justified by the somewhat
random, exploratory nature of the creative mind, and indeed it has
been used in computer music composition for many years.  In this
chapter we will explore several sources of random numbers and how to
use them in generating simple melodies.  With this foundation you will
hopefully be able to use randomness in more sophisticated ways in your
compositions.  Music relying at least to some degree on randomness is
said to be \emph{stochastic}, or \emph{aleatoric}.

\section{Random Numbers}
\label{sec:random}

This section describes the basic functionality of Haskell's
|System.Random| module, which is a library for random numbers.  The
library presents a fairly abstract interface that is structured in two
layers of type classes: one that captures the notion of a \emph{random
  generator}, and one for using a random generator to create
\emph{random sequences}.

We can create a random number generator using the built-in |mkStdGen|
function:
\begin{spec}
mkStdGen :: Int -> StdGen
\end{spec}
which takes an |Int| seed as argument, and returns a ``standard
generator'' of type |StdGen|.  For example, we can define:
\begin{code}
sGen :: StdGen
sGen = mkStdGen 42
\end{code}
We will use this single random generator quite extensively in the
remainder of this chapter.

|StdGen| is an instance of |Show|, and thus its values can be
printed---but they appear in a rather strange way, basically as two
integers.  Try typing |sGen| to the GHCi prompt.

More importantly, |StdGen| is an instance of the |RandomGen| class:
\begin{spec}
class RandomGen g where
  genRange  :: g -> (Int, Int)
  next      :: g -> (Int, g)
  split     :: g -> (g, g)
\end{spec}
The reason that |Int|s are used here is that essentially all
pseudo-random number generator algorithms are based on a
fixed-precision binary number, such as |Int|.  We will see later how
this can be coerced into other number types.

For now, try applying the operators in the above class to the |sGen|
value above.  The |next| function is particularly important, as it
generates the next random number in a sequence as well as a new random
number generator, which in turn can be used to generate the next
number, and so on.  It should be clear that we can then create an
infinite list of random |Int|s like this:
\begin{code}
randInts :: StdGen -> [Int]
randInts g =  let (x,g') = next g
              in x : randInts g'
\end{code}
Look at the value |take 10 (randInts sGen)| to see a sample output.

To support other number types, the |Random| library defines this type
class:
\begin{spec}
class Random a where
   randomR    :: RandomGen g => (a, a) -> g -> (a, g)
   random     :: RandomGen g => g -> (a, g)

   randomRs   :: RandomGen g => (a, a) -> g -> [a]
   randoms    :: RandomGen g => g -> [a]

   randomRIO  :: (a,a) -> IO a
   randomIO   :: IO a
\end{spec}
Built-in instances of |Random| are provided for |Int|, |Integer|,
|Float|, |Double|, |Bool|, and |Char|.

The set of operators in the |Random| class is rather daunting, so
let's focus on just one of them for now, namely the third one,
|RandomRs|, which is also perhaps the most useful one.  This function
takes a random number generator (such as |sGen|), along with a range
of values, and generates an infinite list of random numbers within the
given range (the pair representing the range is treated as a closed
interval).  Here are several examples of this idea:
\begin{code}
randFloats :: [Float]
randFloats = randomRs (-1,1) sGen

randIntegers :: [Integer]
randIntegers = randomRs (0,100) sGen

randString :: String
randString = randomRs ('a','z') sGen
\end{code}
Recall that a string is a list of characters, so we choose here to use
the name |randString| for our infinite list of characters.  If you
believe the story about a monkey typing a novel, then you might
believe that |randString| contains something interesting to read.

So far we have used a seed to initialize our random number generators,
and this is good in the sense that it allows us to generate
repeatable, and therefore more easily testable, results.  If instead
you prefer a non-repeatable result, in which you can think of the seed
as being the time of day when the program is executed, then you need
to use a function that is in the IO monad.  The last two operators in
the |Random| class serve this purpose.  For example, consider:
\begin{code}
randIO :: IO Float
randIO = randomRIO (0,1)
\end{code}
If you repeatedly type |randIO| at the GHCi prompt, it will return a
different random number every time.  This is clearly not purely
``functional,'' and is why it is in the IO monad.  As another example:
\begin{code}
randIO' :: IO ()
randIO' = do  r1 <- randomRIO (0,1) :: IO Float
              r2 <- randomRIO (0,1) :: IO Float
              print (r1 == r2)
\end{code}
will almost always return |False|, because the chance of two randomly 
generated floating point numbers being the same is exceedingly small.  
(The type signature is needed
to ensure that the value generated has an unambigous type.)

\syn{|print :: Show a => a -> IO ()| converts any showable value into
a string, and displays the result in the standard output area.}

\section{Probability Distributions}

The random number generators described in the previous section are
assumed to be \emph{uniform}, meaning that the probability of
generating a number within a given interval is the same everywhere in
the range of the generator.  For example, in the case of |Float| (that
purportedly represents \emph{continuous} real numbers), suppose we are
generating numbers in the range $0$ to $10$.  Then we would expect the
probability of a number appearing in the range $2.3$-$2.4$ to be the
same as the probability of a number appearing in the range
$7.6$-$7.7$, namely $0.01$, or $1\%$ (i.e.\ $0.1/10$).  In the case of
|Int| (a \emph{discrete} or \emph{integral} number type), we would
expect the probability of generating a 5 to be the same as generating
an 8.  In both cases, we say that we have a \emph{uniform
  distribution}.

But we don't always want a uniform distribution.  In generating music,
in fact, it's often the case that we want some kind of a non-uniform
distribution.  Mathematically, the best way to describe a distribution
is by plotting how the probability changes over the range of values
that it produces.  In the case of continuous numbers, this is called
the \emph{probability density function}, which has the property that
its integral over the full range of values is equal to $1$.  

The |System.Random.Distributions| library provides a number of
different probability distributions, which are described below.
Figure \ref{fig:distributions} shows the probability density functions
for each of othem.

\begin{figure}
\centering
\subfigure[Linear]{
\includegraphics[scale=0.9]{pics/linear.eps}
}
\subfigure[Exponential]{
\includegraphics[scale=0.9]{pics/exponential.eps}
}
\subfigure[Bilateral exponential]{
\includegraphics[scale=0.9]{pics/bilexp.eps}
}
\subfigure[Gaussian]{
\includegraphics[scale=0.9]{pics/gaussian.eps}
}
\subfigure[Cauchy]{
\includegraphics[scale=0.9]{pics/cauchy.eps}
}
\subfigure[Poisson]{
\includegraphics[scale=0.9]{pics/poisson.eps}
}
\caption{Various Probability Density Functions}
\label{fig:distributions}
\end{figure}

Here is a list and brief description of each random number generator:
\begin{description}
\item[linear] Generates a \emph{linearly} distributed random variable
  between 0 and 1.  The probability density function is given by:
\[ f(x) = \left\{ \begin{array}{ll}
                  2(1-x) & \mbox{if $0 \leq x \leq 1$} \\
                  0      & \mbox{otherwise}
                  \end{array}
          \right.
\]
The type signature is:
\begin{spec}
linear ::  (RandomGen g, Floating a, Random a, Ord a) => 
           g -> (a,g)
\end{spec}
The mean value of the linear distribution is $1/3$.

\item[exponential] Generates an \emph{exponentially} distributed
  random variable given a spread parameter $\lambda$.  A larger spread
  increases the probability of generating a small number.  The mean of
  the distribution is $1/\lambda$.  The range of the generated
  number is conceptually $0$ to $\infty$, although the chance of
  getting a very large number is very small.  The probability density
  function is given by:
\[ f(x) = \lambda e^{-\lambda x} \]
The type signature is:
\begin{spec}
exponential ::  (RandomGen g, Floating a, Random a) => 
                a -> g -> (a,g)
\end{spec}
The first argument is the parameter $\lambda$.

\item[bilateral exponential] Generates a random number with a
  \emph{bilateral exponential} distribution.  It is similar to 
  exponential,
  but the mean of the distribution is 0 and 50\% of the results fall
  between $-1/\lambda$ and $1/\lambda$.  The probability density
  function is given by:
\[ f(x) = \frac{1}{2}\lambda e^{-\lambda ||x||} \]
The type signature is:
\begin{spec}
bilExp ::  (Floating a, Ord a, Random a, RandomGen g) =>
           a -> g -> (a,g)
\end{spec}

\item[Gaussian] Generates a random number with a \emph{Gaussian}, also
  called \emph{normal}, distribution, given mathematically by:
\[ f(x) = \frac{1}{\sigma\sqrt{2\pi}}
          e^{-\frac{(x-\mu)^2}{2\sigma^2}}
\]
where $\sigma$ is the \emph{standard deviation}, and $\mu$ is the
\emph{mean}.  The type signature is:
\begin{spec}
gaussian ::  (Floating a, Random a, RandomGen g) =>
             a -> a -> g -> (a,g)
\end{spec}
The first argument is the standard deviation $\sigma$ and the second
is the mean $\mu$.  Probabilistically, about 68.27\% of the numbers in
a Gaussian distribution fall within $\pm\sigma$ of the mean; about
$95.45\%$ are within $\pm 2\sigma$, and $99.73\%$ are within
$\pm 3\sigma$.

\item[Cauchy] Generates a \emph{Cauchy}-distributed random variable.
  The distribution is symmetric with a mean of 0.  The density
  function is given by:
\[ f(x) = \frac{\alpha}{\pi(\alpha^2 + x^2)} \]
As with the Gaussian distribution, it is unbounded both above and
below the mean, but at its extremes it approaches 0 more slowly than
the Gaussian.  The type signature is:
\begin{spec}
cauchy ::  (Floating a, Random a, RandomGen g) =>
           a -> g -> (a,g)
\end{spec}
The first argument corresponds to $\alpha$ above, and is called the
\emph{density}.

\item[Poisson] Generates a \emph{Poisson}-distributed random variable.
  The Poisson distribution is discrete, and generates only
  non-negative numbers.  $\lambda$ is the mean of the distribution.
  If $\lambda$ is an integer, the probability that the result is 
  $j = \lambda-1$ is the same as that of $j = \lambda$.  The
  probability of generating the number $j$ is given by:
\[ P\{X=j\} = \frac{\lambda^j}{j!} e^{-\lambda} \]
The type signature is:
\begin{spec}
poisson ::  (  Num t, Ord a, Floating a, Random a
               RandomGen g ) =>
            a -> g -> (t, g)
\end{spec}

\item[Custom] Sometimes it is useful to define one's own discrete
  probability distribution function, and to generate random numbers
  based on it.  The function |frequency| does this---given a list of
  weight-value pairs, it generates a value randomly picked from the
  list, weighting the probability of choosing each value by the given
  weight.
\begin{spec}
frequency ::  (Floating w, Ord w, Random w, RandomGen g) =>
              [(w, a)] -> g -> (a,g)
\end{spec}
\end{description}

\subsection{Random Melodies and Random Walks}

Note that each of the non-uniform distribution random number
generators described in the last section takes zero or more parameters
as arguments, along with a uniform random number generator, and
returns a pair consisting of the next random number and a new
generator.  In other words, the tail end of each type signature has
the form:
\begin{spec}
... -> g -> (a,g)
\end{spec}
where |g| is the type of the random number generator, and |a| is the
type of the next value generated.

Given such a function, we can generate an infinite sequence of random
numbers with the given distribution in a way similar to what we did
earlier for |randInts|.  In fact the following function is defined in
the |Distributions| library to make this easy:
\begin{spec}
rands      ::  (RandomGen g, Random a) => 
               (g -> (a,g)) -> g -> [a]
rands f g  = x : rands f g' where (x,g') = f g
\end{spec}

Let's work through a few musical examples.  One thing we will need to
do is convert a floating point number to an absolute pitch:
\begin{code}
toAbsP1    :: Float -> AbsPitch
toAbsP1 x  = round (40*x + 30)
\end{code}
This function converts a number in the range $0$ to $1$ into an
absolute pitch in the range $30$ to $70$.

And as we have often done, we will also need to convert an absolute
pitch into a note, and a sequence of absolute pitches into a melody:
\begin{code}
mkNote1  :: AbsPitch -> Music Pitch
mkNote1  = note tn . pitch

mkLine1        :: [AbsPitch] -> Music Pitch
mkLine1 rands  = line (take 32 (map mkNote1 rands))
\end{code}

With these functions in hand, we can now generate sequences of random
numbers with a variety of distributions, and convert each of them into
a melody.  For example:
\begin{code}
-- uniform distribution
m1 :: Music Pitch
m1 = mkLine1 (randomRs (30,70) sGen)

-- linear distribution
m2 :: Music Pitch
m2 =  let rs1 = rands linear sGen
      in mkLine1 (map toAbsP1 rs1)

-- exponential distribution
m3      :: Float -> Music Pitch
m3 lam  =  let rs1 = rands (exponential lam) sGen
           in mkLine1 (map toAbsP1 rs1)

-- Gaussian distribution
m4          :: Float -> Float -> Music Pitch
m4 sig mu   =  let rs1 = rands (gaussian sig mu) sGen
               in mkLine1 (map toAbsP1 rs1)
\end{code}

\vspace{.1in}\hrule

\begin{exercise}{\em
Try playing each of the above melodies, and listen to the musical
differences.  For |lam|, try values of $0.1$, $1$, $5$, and $10$.  For
|mu|, a value of $0.5$ will put the melody in the central part of the
scale range---then try values of $0.01$, $0.05$, and $0.1$ for |sig|.}
\end{exercise}

\begin{exercise}{\em 
Do the following:
\begin{itemize}
\item
Try using some of the other probability distributions to generate a
melody.
\item
Instead of using a chromatic scale, try using a diatonic or pentatonic
scale.
\item
Try using randomness to control parameters other than pitch---in
particular, duration and/or volume.
\end{itemize}
}
\end{exercise}

\vspace{.1in}\hrule
\vspace{.1in}

Another approach to generating a melody is sometimes called a
\emph{random walk}.  The idea is to start on a particular note, and
treat the sequence of random numbers as \emph{intervals}, rather than
as pitches.  To prevent the melody from wandering too far from the
starting pitch, one should use a probability distribution whose mean
is zero.  This comes for free with something like the bilateral
exponential, and is easily obtained with a distribution that takes the
mean as a parameter (such as the Gaussian), but is also easily
achieved for other distributions by simply subtracting the mean.  To
see these two situations, here are random melodic walks using first
a Gaussian and then an exponential distribution:
\begin{code}
-- Gaussian distribution with mean set to 0
m5      :: Float -> Music Pitch
m5 sig  =  let rs1 = rands (gaussian sig 0) sGen
           in mkLine2 50 (map toAbsP2 rs1)

-- exponential distribution with mean adjusted to 0
m6      :: Float -> Music Pitch
m6 lam  =  let rs1 = rands (exponential lam) sGen
           in mkLine2 50 (map (toAbsP2 . subtract (1/lam)) rs1)

toAbsP2     :: Float -> AbsPitch
toAbsP2 x   = round (5*x)

mkLine2 :: AbsPitch -> [AbsPitch] -> Music Pitch
mkLine2 start rands = 
   line (take 64 (map mkNote1 (scanl (+) start rands)))
\end{code}
Note that |toAbsP2| does something reasonable to interpret a
floating-point number as an interval, and |mkLine2| uses |scanl| to
generate a ``running sum'' that represents the melody line.

\out{
-- Test code to see how accurate the mean is:
\begin{code}
m2' = let rs1 = rands linear sGen
      in sum (take 1000 rs1) / 1000 :: Float

m5' sig = let rs1 = rands (gaussian sig 0) sGen
          in sum (take 1000 rs1)

m6' lam = let rs1 = rands (exponential lam) sGen
              rs2 = map (subtract (1/lam)) rs1
          in sum (take 1000 rs2)
\end{code}
}

%% \begin{exercise}{\em
%% Instead of ...}
%% \end{exercise}

\section{Markov Chains}

Each number in the random number sequences that we have described thus
far is \emph{independent} of any previous values in the sequence.
This is like flipping a coin---each flip has a 50\% chance of being
heads or tails, i.e.\ it is independent of any previous flips, even if
the last ten flips were all heads.

Sometimes, however, we would like the probability of a new choice to
depend upon some number of previous choices.  This is called a
\emph{conditional probability}.  In a discrete system, if we look only
at the previous value to help determine the next value, then these
conditional probabilities can be conveniently represented in a matrix.
For example, if we are choosing between the pitches $C$, $D$, $E$, and
$F$, then Table \ref{fig:markov-table} might represent the conditional
probabilities of each possible outcome.  The previous pitch is found
in the left column---thus note that the sum of each row is $1.0$.  So,
for example, the probability of choosing a $D$ given that the previous
pitch was an $E$ is $0.6$, and the probability of an $F$ occurring
twice in succession is $0.2$.  The resulting stochastic system is 
called a \emph{Markov Chain}.

\begin{table}
\begin{center}
\begin{tabular}{||l||l||l||l||l||} \hline
    & |C| & |D| & |E| & |F| \\ \hline
|C| & 0.4 & 0.2 & 0.2 & 0.2 \\ \hline
|D| & 0.3 & 0.2 & 0.0 & 0.5 \\ \hline
|E| & 0.1 & 0.6 & 0.1 & 0.2 \\ \hline
|F| & 0.2 & 0.3 & 0.3 & 0.2 \\ \hline
\end{tabular}
\end{center}
\caption{Second-Order Markov Chain}
\label{fig:markov-table}
\end{table}

This idea can of course be generalized to arbitrary numbers of
previous events, and in general an $(n+1)$-dimensional array can be
used to store the various conditional probabilities.  The number of
previous values observed is called the \emph{order} of the Markov
Chain.

[TO DO: write the Haskell code to implement this]

\subsection{Training Data}

Instead of generating the conditional probability table ourselves,
another approach is to use \emph{training data} from which the
conditional probabilities can be \emph{inferred}.  This is handy for
music, because it means that we can feed in a bunch of melodies that
we like, including melodies written by the masters, and use that as a
stochastic basis for generating new melodies.

[TO DO: Give some pointers to the literatue, in particular David
  Cope's work.]

The |Data.MarkovChain| library provides this functionality through a
function called |run|, whose type signature is:
\begin{spec}
run ::  (Ord a, RandomGen g) =>
        Int     -- order of Markov Chain
        -> [a]  -- training sequence (treated as circular list)
        -> Int  -- index to start within the training sequence
        -> g    -- random number generator
        -> [a]
\end{spec}
The |runMulti| function is similar, except that it takes a list of
training sequences as input, and returns a list of lists as its
result, each being an independent random walk whose probabilities are
based on the training data.  The following examples demonstrate how to
use these functions.

\begin{code}
-- some sample training sequences
ps0,ps1,ps2 :: [Pitch]
ps0  = [(C,4), (D,4), (E,4)]
ps1  = [(C,4), (D,4), (E,4), (F,4), (G,4), (A,4), (B,4)]
ps2  = [  (C,4), (E,4), (G,4), (E,4), (F,4), (A,4), (G,4), (E,4),
          (C,4), (E,4), (G,4), (E,4), (F,4), (D,4), (C,4)]

-- functions to package up |run| and |runMulti|
mc    ps   n = mkLine3 (M.run n ps 0 (mkStdGen 42))
mcm   pss  n = mkLine3 (concat (M.runMulti  n pss 0 
                                            (mkStdGen 42)))

-- music-making functions
mkNote3     :: Pitch -> Music Pitch
mkNote3     = note tn

mkLine3     :: [Pitch] -> Music Pitch
mkLine3 ps  = line (take 64 (map mkNote3 ps))
\end{code}

\out{
\begin{code}
-- testing the Markov output directly
lc  ps n    = take 1000 (M.run n ps 0 (mkStdGen 42))
lcl pss n m = take 1000 (M.runMulti n pss 0 (mkStdGen 42) !! m)
\end{code}
}

Here are some things to try with the above definitions:
\begin{itemize}
\item
|mc ps0 0| will generate a completely random sequence, since it is a
``zeroth-order'' Markov Chain that does not look at any previous
output.
\item
|mc ps0 1| looks back one value, which is enough in the case of this
simple training sequence to generate an endless sequence of notes that
sounds just like the training data.  Using any order higher than 1
generates the same result.
\item
|mc ps1 1| also generates a result that sounds just like its training
data.
\item
|mc ps2 1|, on the other hand, has some (random) variety to it,
because the training data has more than one occurrence of most of the
notes.  If we increase the order, however, the output will sound more
and more like the training data.
\item
|mcm [ps0,ps2] 1| and |mcm [ps1,ps2] 1| generate perhaps the most
interesting results yet, in which you can hear aspects of both the
ascending melodic nature of |ps0| and |ps1|, and the harmonic
structure of |ps2|.
\item 
|mcm [ps1,reverse ps1] 1| has, not suprisingly, both ascending and
descending lines in it, as reflected in the training data.
\end{itemize}

\vspace{.1in}\hrule

\begin{exercise}{\em
Play with Markov Chains.  Use them to generate more melodies, or to
control other aspects of the music, such as rhythm.  Also consider
other kinds of training data rather than simply sequences of pitches.}
\end{exercise}

\vspace{.1in}\hrule



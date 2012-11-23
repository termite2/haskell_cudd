{-# LANGUAGE ForeignFunctionInterface, CPP, FlexibleContexts, RankNTypes #-}

module Cudd (
    DdManager(),
    DdNode(),
    cuddInit,
    cuddInitOrder,
    cuddReadOne,
    cuddReadLogicZero,
    cuddBddIthVar,
    cuddBddAnd,
    cuddBddOr,
    cuddBddNand,
    cuddBddNor,
    cuddBddXor,
    cuddBddXnor,
    cuddNot,
    cuddDumpDot,
    cudd_cache_slots,
    cudd_unique_slots,
    cuddEval,
    cuddPrintMinterm,
    cuddAllSat,
    cuddOneSat,
    cuddOnePrime,
    cuddSupportIndex,
    cuddBddExistAbstract,
    cuddBddUnivAbstract,
    cuddBddIte,
    cuddBddPermute,
    cuddBddShift,
    cuddBddSwapVariables,
    cuddNodeReadIndex,
    cuddDagSize,
    cuddIndicesToCube,
    getManagerST,
    getSTManager,
    getNodeST,
    cuddBddLICompaction,
    cuddBddMinimize,
    cuddReadSize,
    cuddXeqy,
    cuddXgty,
    cuddBddInterval,
    cuddDisequality,
    cuddInequality,
    bddToString,
    bddFromString,
    ddNodeToInt,
    cuddBddImp,
    cuddBddPickOneMinterm,
    cuddReadPerm,
    cuddReadInvPerm,
    cuddReadPerms,
    cuddReadInvPerms,
    cuddReadTree,
    cuddCountLeaves,
    cuddCountMinterm,
    cuddCountPath,
    cuddCountPathsToNonZero,
    cuddPrintDebug,
    STDdNode,
    STDdManager, 
    cuddBddAndAbstract,
    cuddBddXorExistAbstract,
    cuddBddTransfer,
    cuddBddMakePrime,
    cuddBddConstrain,
    cuddBddRestrict,
    cuddBddSqueeze,
    SatBit(..),
    cuddLargestCube,
    cuddBddLeq,
    cuddDebugCheck,
    cuddCheckKeys
    ) where

import System.IO
import System.Directory
import Foreign
import Foreign.Ptr
import Foreign.C.Types
import Foreign.C.String
import Foreign.ForeignPtr
import Foreign.Marshal.Array
import Foreign.Marshal.Utils
import Control.Monad.ST.Lazy
import Control.Monad
import Data.Binary
import Data.List
import Control.DeepSeq
import Control.Monad.Error
import Data.Array hiding (indices)
import Control.Exception hiding (catch)

import ForeignHelpers
import CuddInternal
import MTR
import CuddC

#include <stdio.h>
#include "cudd.h"
#include "cuddwrap.h"
#include "dddmp.h"

cuddInit :: DdManager
cuddInit = DdManager $ unsafePerformIO $ c_cuddInit 0 0 (fromIntegral cudd_unique_slots) (fromIntegral cudd_cache_slots) 0

cuddInitOrder :: [Int] -> DdManager
cuddInitOrder order = DdManager $ unsafePerformIO $ withArrayLen (map fromIntegral order) $ \size ptr -> do
    when (sort order /= [0..size-1]) (error "cuddInitOrder: order does not contain each variable once") 
    m <- c_cuddInit (fromIntegral size) 0 (fromIntegral cudd_unique_slots) (fromIntegral cudd_cache_slots) 0
    res <- c_cuddShuffleHeap m ptr
    when (fromIntegral res /= 1) (error "shuffleHeap failed")
    return m

getManagerST :: STDdManager s u -> DdManager
getManagerST (STDdManager m) = DdManager m

getSTManager :: DdManager -> STDdManager s u
getSTManager (DdManager m) = STDdManager m

getNodeST :: STDdNode s u -> DdNode
getNodeST (STDdNode n) = DdNode n

cuddReadOne :: DdManager -> DdNode
cuddReadOne (DdManager d) = DdNode $ unsafePerformIO $ do
	node <- c_cuddReadOne d
	newForeignPtrEnv deref d node

cuddReadLogicZero :: DdManager -> DdNode
cuddReadLogicZero (DdManager d) = DdNode $ unsafePerformIO $ do
	node <- c_cuddReadLogicZero d
	newForeignPtrEnv deref d node

cuddBddIthVar :: DdManager -> Int -> DdNode
cuddBddIthVar (DdManager d) i = DdNode $ unsafePerformIO $ do
	node <- c_cuddBddIthVar d (fromIntegral i)
	newForeignPtr_ node

cuddArg1 :: (Ptr CDdManager -> Ptr CDdNode -> IO (Ptr CDdNode)) -> DdManager -> DdNode -> DdNode
cuddArg1 f (DdManager m) (DdNode x) = DdNode $ unsafePerformIO $ 
	withForeignPtr x $ \xp -> do
	node <- f m xp
	newForeignPtrEnv deref m node

cuddArg2 :: (Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)) -> DdManager -> DdNode -> DdNode -> DdNode
cuddArg2 f (DdManager m) (DdNode l) (DdNode r) = DdNode $ unsafePerformIO $ 
 	withForeignPtr l $ \lp -> 
	withForeignPtr r $ \rp -> do
	node <- f m lp rp
	newForeignPtrEnv deref m node

cuddArg3 :: (Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)) -> DdManager -> DdNode -> DdNode-> DdNode -> DdNode
cuddArg3 f (DdManager m) (DdNode l) (DdNode r) (DdNode x) = DdNode $ unsafePerformIO $ 
 	withForeignPtr l $ \lp -> 
	withForeignPtr r $ \rp -> 
	withForeignPtr x $ \xp -> do
	node <- f m lp rp xp
	newForeignPtrEnv deref m node

cuddBddAnd :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddAnd = cuddArg2 c_cuddBddAnd

cuddBddOr :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddOr = cuddArg2 c_cuddBddOr

cuddBddNand :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddNand = cuddArg2 c_cuddBddNand

cuddBddNor :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddNor = cuddArg2 c_cuddBddNor

cuddBddXor :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddXor = cuddArg2 c_cuddBddXor

cuddBddXnor :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddXnor = cuddArg2 c_cuddBddXnor

cuddNot :: DdManager -> DdNode -> DdNode
cuddNot = cuddArg1 (const c_cuddNot)

foreign import ccall safe "cuddwrap.h &deref"
	derefHook :: FunPtr (Ptr CDdManager -> Ptr CDdNode -> IO ())

foreign import ccall safe "cuddwrap.h wrappedCuddDumpDot"
	c_cuddDumpDot :: Ptr CDdManager -> Ptr CDdNode -> CString -> IO ()

cuddDumpDot :: DdManager -> DdNode -> String -> IO ()
cuddDumpDot (DdManager m) (DdNode n) s  = 
	withForeignPtr n $ \np -> 
		withCAString s $ \str -> 
			c_cuddDumpDot m np str

foreign import ccall safe "cuddwrap.h wrappedCuddIsComplement"
    c_cuddIsComplement :: Ptr CDdNode -> CInt

foreign import ccall safe "cudd.h Cudd_Eval"
    c_cuddEval :: Ptr CDdManager -> Ptr CDdNode -> Ptr CInt -> IO (Ptr CDdNode)

cuddEval :: DdManager -> DdNode -> [Int] -> Bool
cuddEval (DdManager m) (DdNode n) a = unsafePerformIO $ do
    res <- withArray (map fromIntegral a) $ \ap -> 
        withForeignPtr n $ \np -> 
            c_cuddEval m np ap
    return $ (==0) $ fromIntegral $ c_cuddIsComplement res

foreign import ccall safe "cudd.h Cudd_PrintMinterm"
    c_cuddPrintMinterm :: Ptr CDdManager -> Ptr CDdNode -> IO ()

cuddPrintMinterm :: DdManager -> DdNode -> IO ()
cuddPrintMinterm (DdManager m) (DdNode n) = 
    withForeignPtr n $ c_cuddPrintMinterm m 

data SatBit = Zero | One | DontCare deriving (Eq)

toSatBit :: Int -> SatBit
toSatBit 0 = Zero
toSatBit 1 = One
toSatBit 2 = DontCare
toSatBit _ = error "toSatBit: Invalid sat bit returned from CUDD"

foreign import ccall safe "cuddwrap.h allSat"
    c_allSat :: Ptr CDdManager -> Ptr CDdNode -> Ptr CInt -> Ptr CInt -> IO (Ptr (Ptr CInt))

foreign import ccall safe "cuddwrap.h oneSat"
    c_oneSat :: Ptr CDdManager -> Ptr CDdNode -> Ptr CInt -> IO (Ptr CInt)

cuddAllSat :: DdManager -> DdNode -> [[SatBit]]
cuddAllSat (DdManager m) (DdNode n) = unsafePerformIO $ 
    alloca $ \nvarsptr -> 
    alloca $ \ntermsptr -> 
    withForeignPtr n $ \np -> do
    res <- c_allSat m np ntermsptr nvarsptr
    nterms <- liftM fromIntegral $ peek ntermsptr
    res <- peekArray nterms res
    nvars <- liftM fromIntegral $ peek nvarsptr
    res <- mapM (peekArray nvars) res
    return $ map (map (toSatBit . fromIntegral)) res

cuddOneSat :: DdManager -> DdNode -> Maybe [SatBit]
cuddOneSat (DdManager m) (DdNode n) = unsafePerformIO $ 
    alloca $ \nvarsptr ->
    withForeignPtr n $ \np -> do
    res <- c_oneSat m np nvarsptr
    if res==nullPtr then (return Nothing) else do
        nvars <- liftM fromIntegral $ peek nvarsptr
        res <- peekArray nvars res
        return $ Just $ map (toSatBit . fromIntegral) res

foreign import ccall safe "cuddwrap.h onePrime"
    c_onePrime :: Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> Ptr CInt -> IO (Ptr CInt)

cuddOnePrime :: DdManager -> DdNode -> DdNode -> Maybe [Int]
cuddOnePrime (DdManager m) (DdNode l) (DdNode u) = unsafePerformIO $ 
    alloca $ \nvarsptr -> 
    withForeignPtr l $ \lp -> 
    withForeignPtr u $ \up -> do
    res <- c_onePrime m lp up nvarsptr 
    if res==nullPtr then (return Nothing) else do
        nvars <- liftM fromIntegral $ peek nvarsptr
        res <- peekArray nvars res
        return $ Just $ map fromIntegral res

cuddReadSize :: DdManager -> Int
cuddReadSize (DdManager m) = fromIntegral $ unsafePerformIO $ c_cuddReadSize m

cuddSupportIndex :: DdManager -> DdNode -> [Bool]
cuddSupportIndex (DdManager m) (DdNode n) = unsafePerformIO $ 
	withForeignPtr n $ \np -> do
    res <- c_cuddSupportIndex m np
    size <- c_cuddReadSize m
    res <- peekArray (fromIntegral size) res
    return $ map toBool res

foreign import ccall safe "cudd.h Cudd_FirstCube"
    c_cuddFirstCube :: Ptr CDdManager -> Ptr CDdNode -> Ptr (Ptr CInt) -> Ptr CInt

cuddBddExistAbstract :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddExistAbstract = cuddArg2 c_cuddBddExistAbstract

cuddBddUnivAbstract :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddUnivAbstract = cuddArg2 c_cuddBddUnivAbstract

cuddBddIte :: DdManager -> DdNode -> DdNode -> DdNode -> DdNode
cuddBddIte = cuddArg3 c_cuddBddIte

cuddBddSwapVariables :: DdManager -> DdNode -> [DdNode] -> [DdNode] -> DdNode
cuddBddSwapVariables (DdManager m) (DdNode d) s1 s2 = DdNode $ unsafePerformIO $ 
    withForeignPtr d $ \dp -> 
    withForeignArrayPtrLen (map unDdNode s1) $ \s1 s1ps -> 
    withForeignArrayPtrLen (map unDdNode s2) $ \s2 s2ps -> do
    when (s1 /= s2) (error "cuddBddSwapVariables: variable lists have different sizes")
    node <- c_cuddBddSwapVariables m dp s1ps s2ps (fromIntegral s1)
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_bddPermute_s"
    c_cuddBddPermute :: Ptr CDdManager -> Ptr CDdNode -> Ptr CInt -> IO (Ptr CDdNode)

cuddBddPermute :: DdManager -> DdNode -> [Int] -> DdNode 
cuddBddPermute (DdManager m) (DdNode d) indexes = DdNode $ unsafePerformIO $ 
    withForeignPtr d $ \dp -> 
    withArray (map fromIntegral indexes) $ \ip -> do
    node <- c_cuddBddPermute m dp ip 
    newForeignPtrEnv deref m node

makePermutArray :: Int -> [Int] -> [Int] -> [Int]
makePermutArray size x y = elems $ accumArray (flip const) 0 (0, size-1) ascList
    where
    ascList = [(i, i) | i <- [0..size-1]] ++ zip x y 

cuddBddShift :: DdManager -> DdNode -> [Int] -> [Int] -> DdNode
cuddBddShift (DdManager m) (DdNode d) from to = DdNode $ unsafePerformIO $
    withForeignPtr d $ \dp -> do
    dp <- evaluate dp
    size <- c_cuddReadSize m 
    let perm = makePermutArray (fromIntegral size) from to
    withArray (map fromIntegral perm) $ \pp -> do
    node <- c_cuddBddPermute m dp pp
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_Xgty_s"
	c_cuddXgty :: Ptr CDdManager -> CInt -> Ptr (Ptr CDdNode) -> Ptr (Ptr CDdNode) -> Ptr (Ptr CDdNode) -> IO (Ptr CDdNode)

cuddXgty :: DdManager -> [DdNode] -> [DdNode] -> DdNode
cuddXgty (DdManager m) x y = DdNode $ unsafePerformIO $ 
    withForeignArrayPtrLen (map unDdNode x) $ \xl xp -> 
    withForeignArrayPtrLen (map unDdNode y) $ \yl yp -> do
    when (xl /= yl) (error "cuddXgty: variable lists have different sizes")
    node <- c_cuddXgty m (fromIntegral xl) nullPtr xp yp
    newForeignPtrEnv deref m node

cuddXeqy :: DdManager -> [DdNode] -> [DdNode] -> DdNode
cuddXeqy (DdManager m) x y = DdNode $ unsafePerformIO $ 
    withForeignArrayPtrLen (map unDdNode x) $ \xl xp -> 
    withForeignArrayPtrLen (map unDdNode y) $ \yl yp -> do
    when (xl /= yl) (error "cuddXeqy: variable lists have different sizes")
    node <- c_cuddXeqy m (fromIntegral xl) xp yp
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_Inequality_s"
	c_cuddInequality :: Ptr CDdManager -> CInt -> CInt -> Ptr (Ptr CDdNode) -> Ptr (Ptr CDdNode) -> IO (Ptr CDdNode)

cuddInequality :: DdManager -> Int -> Int -> [DdNode] -> [DdNode] -> DdNode
cuddInequality (DdManager m) n c x y = DdNode $ unsafePerformIO $ 
    withForeignArrayPtr (map unDdNode x) $ \xp -> 
    withForeignArrayPtr (map unDdNode y) $ \yp -> do
    node <- c_cuddInequality m (fromIntegral n) (fromIntegral c) xp yp
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_Disequality_s"
	c_cuddDisequality :: Ptr CDdManager -> CInt -> CInt -> Ptr (Ptr CDdNode) -> Ptr (Ptr CDdNode) -> IO (Ptr CDdNode)

cuddDisequality :: DdManager -> Int -> Int -> [DdNode] -> [DdNode] -> DdNode
cuddDisequality (DdManager m) n c x y = DdNode $ unsafePerformIO $
    withForeignArrayPtr (map unDdNode x) $ \xp -> 
    withForeignArrayPtr (map unDdNode y) $ \yp -> do
    node <- c_cuddDisequality m (fromIntegral n) (fromIntegral c) xp yp
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_bddInterval_s"
    c_cuddBddInterval :: Ptr CDdManager -> CInt -> Ptr (Ptr CDdNode) -> CInt -> CInt -> IO (Ptr CDdNode)

cuddBddInterval :: DdManager -> [DdNode] -> Int -> Int -> DdNode
cuddBddInterval (DdManager m) vararr lower upper =  DdNode $ unsafePerformIO $ 
    withForeignArrayPtrLen (map unDdNode vararr) $ \sz vp -> do
    node <- c_cuddBddInterval m (fromIntegral sz) vp (fromIntegral lower) (fromIntegral upper)
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_NodeReadIndex"
    c_cuddNodeReadIndex :: Ptr CDdNode -> IO CInt

cuddNodeReadIndex :: DdNode -> Int
cuddNodeReadIndex (DdNode d) = fromIntegral $ unsafePerformIO $ withForeignPtr d c_cuddNodeReadIndex 

foreign import ccall safe "cudd.h Cudd_DagSize"
    c_cuddDagSize :: Ptr CDdNode -> IO CInt

cuddDagSize (DdNode d) = fromIntegral $ unsafePerformIO $ withForeignPtr d c_cuddDagSize 

cuddIndicesToCube :: DdManager -> [Int] -> DdNode
cuddIndicesToCube (DdManager m) indices = DdNode $ unsafePerformIO $ 
    withArrayLen (map fromIntegral indices) $ \size ip -> do
    node <- c_cuddIndicesToCube m ip (fromIntegral size)
    newForeignPtrEnv deref m node

foreign import ccall safe "cudd.h Cudd_bddLICompaction_s"
    c_cuddBddLICompaction :: Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)

cuddBddLICompaction :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddLICompaction = cuddArg2 c_cuddBddLICompaction

foreign import ccall safe "cudd.h Cudd_bddMinimize_s"
    c_cuddBddMinimize :: Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)

cuddBddMinimize :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddMinimize = cuddArg2 c_cuddBddMinimize


newtype Dddmp_VarInfoType = Dddmp_VarInfoType {varInfoTypeVal :: CInt}
#{enum Dddmp_VarInfoType, Dddmp_VarInfoType
  , dddmp_varids      = DDDMP_VARIDS
  , dddmp_varpermids  = DDDMP_VARPERMIDS
  , dddmp_varauxids   = DDDMP_VARAUXIDS
  , dddmp_varnames    = DDDMP_VARNAMES
  , dddmp_vardefault  = DDDMP_VARDEFAULT
  }

newtype Dddmp_Mode = Dddmp_Mode {dddmpMode :: CInt}
#{enum Dddmp_Mode, Dddmp_Mode
  , dddmp_mode_text    = DDDMP_MODE_TEXT
  , dddmp_mode_binary  = DDDMP_MODE_BINARY
  , dddmp_mode_default = DDDMP_MODE_DEFAULT
  }


newtype Dddmp_Status = Dddmp_Status {dddmpStatus :: CInt} deriving (Eq, Show)
#{enum Dddmp_Status, Dddmp_Status
  , dddmp_failure    = DDDMP_FAILURE
  , dddmp_success    = DDDMP_SUCCESS
  } 


foreign import ccall safe "dddmp.h Dddmp_cuddBddStore"
    c_dddmpBddStore :: Ptr CDdManager -> CString -> Ptr CDdNode -> Ptr CString -> Ptr CInt -> CInt -> CInt -> CString -> Ptr CFile -> IO CInt

cuddBddStore :: DdManager -> String -> DdNode -> [Int] -> Dddmp_Mode -> Dddmp_VarInfoType -> String -> IO Dddmp_Status
cuddBddStore (DdManager m) name (DdNode node) auxids mode varinfo fname = do
    pauxids <- case auxids of
                [] -> return nullPtr
                _ -> newArray (map fromIntegral auxids :: [CInt])
    withForeignPtr node $ \dp -> do 
    withCString name $ \pname -> do
    withCString fname $ \pfname -> do
        ret <- c_dddmpBddStore m pname dp nullPtr pauxids (dddmpMode mode) (varInfoTypeVal varinfo) pfname nullPtr
        return $ Dddmp_Status ret

-- Extremely ugly and unsafe way to convert BDD to String via file
bddToString :: (MonadError String me) => DdManager -> DdNode -> me String
bddToString m node = unsafePerformIO $ 
    catch (do let fname = show (unDdNode node) ++ ".bdd"
              ret <- cuddBddStore m fname node [] dddmp_mode_text dddmp_varids fname
              --putStrLn $ "ret = " ++ (show ret)
              if ret == dddmp_success
                      then do str <- readFile fname
                              removeFile fname
                              return $ return str
                      else return $ throwError $ "Failed to serialise BDD (status: " ++ show (dddmpStatus ret) ++ ")")
          (return . throwError . show)
    

newtype Dddmp_VarMatchType = Dddmp_VarMatchType {dddmpMatchType :: CInt} deriving (Eq, Show)
#{enum Dddmp_VarMatchType, Dddmp_VarMatchType
  , dddmp_var_matchids     = DDDMP_VAR_MATCHIDS
  , dddmp_var_matchpermids = DDDMP_VAR_MATCHPERMIDS
  , dddmp_var_matchauxids  = DDDMP_VAR_MATCHAUXIDS
  , dddmp_var_matchnames   = DDDMP_VAR_MATCHNAMES
  , dddmp_var_composeids   = DDDMP_VAR_COMPOSEIDS
  } 

foreign import ccall safe "dddmp.h Dddmp_cuddBddLoad_s"
    c_dddmpBddLoad :: Ptr CDdManager -> CInt -> Ptr CString -> Ptr CInt -> Ptr CInt -> CInt -> CString -> Ptr CFile -> IO (Ptr CDdNode)

cuddBddLoad :: DdManager -> Dddmp_VarMatchType -> [Int] -> [Int] -> Dddmp_Mode -> String -> IO DdNode
cuddBddLoad (DdManager m) matchtype auxids composeids mode fname = do
    pauxids <- case auxids of
                 [] -> return nullPtr
                 _ -> newArray (map fromIntegral auxids :: [CInt])
    pcomposeids <- case auxids of
                     [] -> return nullPtr
                     _ -> newArray (map fromIntegral composeids :: [CInt])
    withCString fname $ \pfname -> do
        node <- c_dddmpBddLoad m (dddmpMatchType matchtype) nullPtr pauxids pcomposeids (dddmpMode mode) pfname nullPtr
        if node == nullPtr
            then ioError $ userError "Dddmp_cuddBddLoad failed"
            else do 
                    fp <- newForeignPtrEnv deref m node
                    return $ DdNode fp

-- BDD from string via file
bddFromString :: MonadError String me => DdManager -> String -> me DdNode
bddFromString m str = unsafePerformIO $ 
    catch (do let fname = "_fromString.bdd"
              writeFile fname str
              node <- cuddBddLoad m dddmp_var_matchids [] [] dddmp_mode_text fname
              removeFile fname
              return $ return node)
          (return . throwError . show)

--Bdd implication
cuddBddImp :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddImp m l r = cuddBddOr m (cuddNot m l) r

cuddBddPickOneMinterm :: DdManager -> DdNode -> [DdNode] -> Maybe DdNode
cuddBddPickOneMinterm (DdManager m) (DdNode d) vars = unsafePerformIO $
	withForeignPtr d $ \dp -> 
	withForeignArrayPtrLen (map unDdNode vars) $ \vs vp -> do
	node <- c_cuddBddPickOneMinterm m dp vp (fromIntegral vs)
	if (node == nullPtr) then return Nothing else do
		nd <- newForeignPtrEnv deref m node
		return $ Just $ DdNode nd

foreign import ccall safe "cudd.h Cudd_PrintInfo"
	c_cuddPrintInfo :: Ptr CDdManager -> Ptr CFile -> IO (CInt)

cuddPrintInfo :: DdManager -> Ptr CFile -> IO (Int)
cuddPrintInfo (DdManager m) cf = liftM fromIntegral $ c_cuddPrintInfo m cf

foreign import ccall safe "cuddWrap.h getStdOut"
	c_getStdOut :: IO (Ptr CFile)

cStdOut = unsafePerformIO c_getStdOut

instance NFData DdNode

foreign import ccall safe "cudd.h Cudd_ReadPerm"
    c_cuddReadPerm :: Ptr CDdManager -> CInt -> IO CInt

cuddReadPerm :: DdManager -> Int -> Int
cuddReadPerm (DdManager m) i = fromIntegral $ unsafePerformIO $ c_cuddReadPerm m (fromIntegral i)

foreign import ccall safe "cudd.h Cudd_ReadInvPerm"
    c_cuddReadInvPerm :: Ptr CDdManager -> CInt -> IO CInt

cuddReadInvPerm :: DdManager -> Int -> Int
cuddReadInvPerm (DdManager m) i = fromIntegral $ unsafePerformIO $ c_cuddReadInvPerm m (fromIntegral i)

cuddReadPerms :: DdManager -> [Int]
cuddReadPerms m = map (cuddReadPerm m) [0..(cuddReadSize m - 1)]

cuddReadInvPerms :: DdManager -> [Int]
cuddReadInvPerms m = map (cuddReadInvPerm m) [0..(cuddReadSize m -1)]

foreign import ccall safe "cudd.h Cudd_ReadTree"
    c_cuddReadTree :: Ptr CDdManager -> IO (Ptr CMtrNode)

cuddReadTree :: DdManager -> IO MtrNode 
cuddReadTree (DdManager m) = liftM MtrNode $ c_cuddReadTree m

foreign import ccall safe "cudd,h Cudd_CountLeaves"
    c_cuddCountLeaves :: Ptr CDdNode -> IO CInt

cuddCountLeaves :: DdNode -> Int
cuddCountLeaves (DdNode d) = fromIntegral $ unsafePerformIO $ 
    withForeignPtr d $ \dp -> 
    c_cuddCountLeaves dp

foreign import ccall safe "cudd.h Cudd_CountMinterm"
    c_cuddCountMinterm :: Ptr CDdManager -> Ptr CDdNode -> CInt -> IO CDouble

cuddCountMinterm :: DdManager -> DdNode -> Int -> Double
cuddCountMinterm (DdManager m) (DdNode d) n = realToFrac $ unsafePerformIO $
    withForeignPtr d $ \dp -> 
    c_cuddCountMinterm m dp (fromIntegral n) 

foreign import ccall safe "cudd.h Cudd_CountPathsToNonZero"
    c_cuddCountPathsToNonZero :: Ptr CDdNode -> IO CDouble

cuddCountPathsToNonZero :: DdNode -> Double
cuddCountPathsToNonZero (DdNode d) = realToFrac $ unsafePerformIO $
    withForeignPtr d $ \dp ->
    c_cuddCountPathsToNonZero dp

foreign import ccall safe "cudd.h Cudd_CountPath"
    c_cuddCountPath :: Ptr CDdNode -> IO CDouble

cuddCountPath :: DdNode -> Double
cuddCountPath (DdNode d) = realToFrac $ unsafePerformIO $
    withForeignPtr d $ \dp -> 
    c_cuddCountPath dp

foreign import ccall safe "cudd.h Cudd_PrintDebug"
    c_cuddPrintDebug :: Ptr CDdManager -> Ptr CDdNode -> CInt -> CInt -> IO (CInt)

cuddPrintDebug :: DdManager -> DdNode -> Int -> Int -> IO (Int)
cuddPrintDebug (DdManager m) (DdNode d) n pr = liftM fromIntegral $ 
    withForeignPtr d $ \dp -> 
    c_cuddPrintDebug m dp (fromIntegral n) (fromIntegral pr)

cuddBddAndAbstract :: DdManager -> DdNode -> DdNode -> DdNode -> DdNode  
cuddBddAndAbstract = cuddArg3 c_cuddBddAndAbstract

cuddBddXorExistAbstract :: DdManager -> DdNode -> DdNode -> DdNode -> DdNode  
cuddBddXorExistAbstract = cuddArg3 c_cuddBddXorExistAbstract

foreign import ccall safe "cudd.h Cudd_bddTransfer"
    c_cuddBddTransfer :: Ptr CDdManager -> Ptr CDdManager -> Ptr CDdNode -> IO (Ptr CDdNode)

cuddBddTransfer :: DdManager -> DdManager -> DdNode -> DdNode
cuddBddTransfer (DdManager m1) (DdManager m2) (DdNode x) = DdNode $ unsafePerformIO $ do
    withForeignPtr x $ \xp -> do
        node <- c_cuddBddTransfer m1 m2 xp
        newForeignPtrEnv deref m2 node

cuddBddMakePrime :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddMakePrime = cuddArg2 c_cuddBddMakePrime

foreign import ccall safe "cudd.h Cudd_bddConstrain_s"
    c_cuddBddConstrain :: Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)

cuddBddConstrain :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddConstrain = cuddArg2 c_cuddBddConstrain

foreign import ccall safe "cudd.h Cudd_bddRestrict_s"
    c_cuddBddRestrict :: Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)

cuddBddRestrict :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddRestrict = cuddArg2 c_cuddBddRestrict

foreign import ccall safe "cudd.h Cudd_bddSqueeze_s" 
    c_cuddBddSqueeze :: Ptr CDdManager -> Ptr CDdNode -> Ptr CDdNode -> IO (Ptr CDdNode)

cuddBddSqueeze :: DdManager -> DdNode -> DdNode -> DdNode
cuddBddSqueeze = cuddArg2 c_cuddBddSqueeze

cuddLargestCube :: DdManager -> DdNode -> (Int, DdNode)
cuddLargestCube (DdManager m) (DdNode n) = unsafePerformIO $ 
    alloca $ \lp ->
    withForeignPtr n $ \np -> do
    node <- c_cuddLargestCube m np lp
    res <- newForeignPtrEnv deref m node
    l <- peek lp
    return (fromIntegral l, DdNode res)
     
cuddBddLeq :: DdManager -> DdNode -> DdNode -> Bool
cuddBddLeq (DdManager m) (DdNode l) (DdNode r) = (==1) $ unsafePerformIO $ do
    withForeignPtr l $ \lp -> do
    withForeignPtr r $ \rp -> do
    c_cuddBddLeq m lp rp

cuddCheckKeys :: DdManager -> ST s ()
cuddCheckKeys (DdManager m) = unsafeIOToST $ c_cuddCheckKeys m

cuddDebugCheck :: DdManager -> ST s ()
cuddDebugCheck (DdManager m) = unsafeIOToST $ c_cuddDebugCheck m


{-# LANGUAGE OverloadedStrings #-}

-- An example hslua program that demonstrates providing Haskell callbacks
-- to Lua and getting Lua callbacks from Haskell.

import qualified Data.ByteString.Char8 as BC
import Data.IORef
import Foreign.C.Types (CInt)
import Foreign.Lua

main :: IO ()
main = do
  callbacks <- newIORef []
  runLua $ do
    openlibs
    registerHaskellFunction "addLuaCallbacks" (addLuaCallbacks callbacks)
    registerHaskellFunction "callLuaCallbacks" (callLuaCallbacks callbacks)
    registerHaskellFunction "resetLuaCallbacks" (resetLuaCallbacks callbacks)
    loadfile "examples/callbacks/callbacks.lua"
    call 0 0

type LuaFunRef = Int

-- | Get Lua callbacks as argument to later call them in order.
-- Successive calls to this function without calling `resetLuaCallbacks`
-- adds more callbacks to the queue.
-- (I know lists are not the best functional queue implementations ...)
addLuaCallbacks :: IORef [LuaFunRef] -> Lua NumResults
addLuaCallbacks cs = do
    -- number of arguments passed to this function
    args <- gettop
    -- make sure arguments are functions
    as <- checkArgs args
    case as of
      Nothing -> do
        -- arguments are functions, add them to callback queue and return
        -- nothing
        addCallbacks 1 args
        return 0
      Just errArg -> do
        -- error: argument at `errArg` is not a function, return error
        -- string
        pushstring $ BC.pack $
          "argument " ++ show errArg ++ " is not a function"
        return 1
  where
    -- | Check if all arguments are functions, return `Just argIdx` if
    -- argument at `argIdx` is not a function and `Nothing` otherwise.
    checkArgs :: StackIndex -> Lua (Maybe StackIndex)
    checkArgs 0 = return Nothing
    checkArgs n = do
      ty <- ltype n
      if ty == TypeFunction
        then checkArgs (n-1)
        else return $ Just n

    addCallbacks :: StackIndex -> StackIndex -> Lua ()
    addCallbacks n max
      | n > max = return ()
      | otherwise = do
          -- move nth argument to top of the stack
          pushvalue n
          -- add function reference to registry
          refId <- ref registryindex
          -- add registry index to IORef
          liftIO $ modifyIORef cs (++ [refId])
          -- continue adding other arguments
          addCallbacks (n+1) max

-- | Call Lua callbacks collected with `addLuaCallbacks`.
callLuaCallbacks :: IORef [LuaFunRef] -> Lua NumResults
callLuaCallbacks cs = do
  cs' <- liftIO $ readIORef cs
  -- push new array to the stack
  createtable (length cs') 0
  -- call callbacks and fill array with return values
  iter cs'
  return 1
 where
  iter [] = return ()
  iter (c : rest) = do
    getglobal' "table.insert"
    pushvalue (-2)
    pushinteger (fromIntegral c)
    gettable registryindex
    -- call the callback
    pcall 0 1 Nothing
    -- call table.insert
    pcall 2 0 Nothing
    iter rest

-- | Reset callback queue and remove Lua functions from registry to enable
-- garbage collection.
resetLuaCallbacks :: IORef [LuaFunRef] -> Lua NumResults
resetLuaCallbacks cs = do
  cs' <- liftIO (readIORef cs)
  mapM_ (unref registryindex) cs'
  liftIO $ writeIORef cs []
  return 0

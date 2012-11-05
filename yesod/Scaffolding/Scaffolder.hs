{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
module Scaffolding.Scaffolder (scaffold) where

import qualified Data.Text.Lazy as LT
import qualified Data.ByteString.Char8 as S
import System.IO
import Text.Shakespeare.Text (textFile, renderTextUrl)
import qualified Data.Text as T
import qualified Data.Text.Lazy.IO as TLIO
import Control.Arrow ((&&&))
import Data.FileEmbed (embedFile)
import Data.String (fromString)
import MultiFile (unpackMultiFile)
import Data.Conduit (yield, ($$), runResourceT)

prompt :: (String -> Maybe a) -> IO a
prompt f = do
    s <- getLine
    case f s of
        Just a -> return a
        Nothing -> do
            putStr "That was not a valid entry, please try again: "
            hFlush stdout
            prompt f

data Backend = Sqlite | Postgresql | Mysql | MongoDB | Simple
  deriving (Eq, Read, Show, Enum, Bounded)

puts :: LT.Text -> IO ()
puts s = TLIO.putStr (LT.init s) >> hFlush stdout

backends :: [Backend]
backends = [minBound .. maxBound]

showBackend :: Backend -> String
showBackend Sqlite = "s"
showBackend Postgresql = "p"
showBackend Mysql = "mysql"
showBackend MongoDB = "mongo"
showBackend Simple = "simple"

readBackend :: String -> Maybe Backend
readBackend s = lookup s $ map (showBackend &&& id) backends

backendBS :: Backend -> S.ByteString
backendBS Sqlite = $(embedFile "hsfiles/sqlite.hsfiles")
backendBS Postgresql = $(embedFile "hsfiles/postgres.hsfiles")
backendBS Mysql = $(embedFile "hsfiles/mysql.hsfiles")
backendBS MongoDB = $(embedFile "hsfiles/mongo.hsfiles")
backendBS Simple = $(embedFile "hsfiles/simple.hsfiles")

-- | Is the character valid for a project name?
validPN :: Char -> Bool
validPN c
    | 'A' <= c && c <= 'Z' = True
    | 'a' <= c && c <= 'z' = True
    | '0' <= c && c <= '9' = True
validPN '-' = True
validPN _ = False

scaffold :: IO ()
scaffold = do
    puts $ renderTextUrl undefined $(textFile "input/welcome.cg")
    project <- prompt $ \s ->
        if all validPN s && not (null s) && s /= "test"
            then Just s
            else Nothing
    let dir = project

    puts $ renderTextUrl undefined $(textFile "input/database.cg")

    backend <- prompt readBackend

    putStrLn "That's it! I'm creating your files now..."

    let sink = unpackMultiFile
                (fromString project)
                (T.replace "PROJECTNAME" (T.pack project))
    runResourceT $ yield (backendBS backend) $$ sink

    TLIO.putStr $ LT.replace "PROJECTNAME" (LT.pack project) $ renderTextUrl undefined $(textFile "input/done.cg")

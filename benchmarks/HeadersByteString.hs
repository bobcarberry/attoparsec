{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
module HeadersByteString (headers) where

import Common (pathTo, rechunkBS)
import Control.Applicative
import Criterion.Main (bench, bgroup, nf)
import Criterion.Types (Benchmark)
import qualified Data.Attoparsec.ByteString.Char8 as B
import qualified Data.Attoparsec.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as B

header = do
  name <- B.takeWhile1 (B.inClass "a-zA-Z0-9_-") <* B.char ':' <* B.skipSpace
  body <- (:) <$> bodyLine <*> many (B.takeWhile1 B.isSpace *> bodyLine)
  return (name, body)

bodyLine = B.takeTill (\c -> c == '\r' || c == '\n') <* B.endOfLine

requestLine =
    (,,) <$>
    (method <* B.skipSpace) <*>
    (B.takeTill B.isSpace <* B.skipSpace) <*>
    httpVersion
  where method = "GET" <|> "POST"

httpVersion = "HTTP/" *> ((,) <$> (int <* B.char '.') <*> int)

responseLine = (,,) <$>
               (httpVersion <* B.skipSpace) <*>
               (int <* B.skipSpace) <*>
               bodyLine

int :: B.Parser Int
int = B.decimal

request = (,) <$> (requestLine <* B.endOfLine) <*> many header

response = (,) <$> responseLine <*> many header

headers :: IO Benchmark
headers = do
  req <- B.readFile =<< pathTo "http-request.txt"
  resp <- B.readFile =<< pathTo "http-response.txt"
  let reql    = rechunkBS 4 req
      respl   = rechunkBS 4 resp
  return $ bgroup "headers" [
      bgroup "B" [
        bench "request" $ nf (B.parseOnly request) req
      , bench "response" $ nf (B.parseOnly response) resp
      ]
    , bgroup "BL" [
        bench "request" $ nf (BL.parse request) reql
      , bench "response" $ nf (BL.parse response) respl
      ]
    ]

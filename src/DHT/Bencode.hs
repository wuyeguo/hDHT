module DHT.Bencode (
    BVal(BInt, BStr, BList, BDict)
  , bencode
  , bdecode)
where

import Text.Printf
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C
import qualified Data.Map.Strict as M
import Text.ParserCombinators.Parsec

data BVal = BInt Integer
    | BStr String
    | BList [BVal]
    | BDict (M.Map BVal BVal)
    deriving (Show,Ord,Eq)

(~~) :: BS.ByteString -> BS.ByteString -> BS.ByteString
(~~) = BS.append

bencode :: BVal -> BS.ByteString
bencode (BStr s) = C.pack $ printf "%d:%s" (length s) s
bencode (BInt i) = C.pack $ printf "i%de" i
bencode (BList bs) = "l" ~~ foldl f "" bs ~~ "e"
    where f :: BS.ByteString -> BVal -> BS.ByteString
          f acc b = acc ~~ bencode b
bencode (BDict map) = "d" ~~ M.foldlWithKey f "" map ~~ "e"
    where f :: BS.ByteString -> BVal -> BVal -> BS.ByteString
          f acc k b = acc ~~ bencode k ~~ bencode b

bdecode :: String -> Either ParseError [BVal]
bdecode = parse (many bparse) ""

----- Parsers
number :: Parser Integer
number = 
    do neg <- try $ string "-" <|> string ""
       numStr <- many1 digit
       return $ read (neg ++ numStr)
bstr :: Parser BVal
bstr = do
    len <- number
    char ':'
    contents <- count (fromIntegral len) anyChar
    return $ BStr contents
bint :: Parser BVal
bint = do
    char 'i'
    num <- number
    char 'e'
    return $ BInt num
blist :: Parser BVal
blist = do
    char 'l'
    xs <- many bparse
    char 'e'
    (return . BList) xs
bdict :: Parser BVal
bdict = do
    char 'd'
    kvPairs <- many1 bDictEntry
    char 'e'
    (return . BDict . M.fromList) kvPairs
bDictEntry :: Parser (BVal, BVal)
bDictEntry = do
    k <- bstr <?> "dict keys must be strings"
    v <- bparse
    return (k,v)
bparse :: Parser BVal
bparse = bint <|> bstr <|> blist <|> bdict

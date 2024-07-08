{-# Language FlexibleContexts, FlexibleInstances #-}
module Network.RTbl.Parser ( parseRTbl_ipv6, parseRTbl_ipv4, rTblToIsabelle, RTbl, Routing_rule)
where

import           Text.Parsec
import           Data.Functor ((<$>), ($>))
import           Control.Applicative ((<*), (*>), (<$>), (<*>))
import qualified Network.IPTables.Generated as Isabelle
import           Network.IPTables.Ruleset
import           Network.IPTables.ParserHelper
import           Network.IPTables.IsabelleToString (Word32, Word128)
import qualified Network.IPTables.Generated as Isabelle
import           Network.IPTables.Generated (metric_update, routing_action_next_hop_update, routing_action_oiface_update, empty_rr_hlp)
import           Data.Maybe (catMaybes, Maybe (Just, Nothing), fromMaybe)
import           Control.Monad (void,liftM)

type Routing_rule a = Isabelle.Routing_rule_ext a ()
data RTbl a = RTbl [Routing_rule a]

parseRTbl ippars = flip runParser () $ RTbl . (\t -> if Isabelle.sanity_ip_route t then t else error "Routing table sanity check failed.") . Isabelle.sort_rtbl <$> manyEOF (parseRTblEntry ippars)

manyEOF f = do
    res <- many f
    eof
    return res

parseRTbl_ipv4 = parseRTbl ipv4dotdecimal
parseRTbl_ipv6 = parseRTbl ipv6colonsep

parseRTblEntry :: Isabelle.Len a => Parsec String s (Isabelle.Word a) -> Parsec String s (Routing_rule a)
parseRTblEntry ippars = do
    blackhole <- parseBlackhole <|> return id
    pfx <- ipaddrOrCidr ippars <|> defaultParser
    skipWS
    opts <- parseOpts ippars
    many1 (char '\n')
    return $ blackhole . opts . empty_rr_hlp $ pfx
    where
        defaultParser = Prelude.const (Isabelle.default_prefix) <$> lit "default"

parseOpt :: Isabelle.Len a => Parsec String s (Isabelle.Word a) -> Parsec String s (Routing_rule a -> Routing_rule a)
parseOpt ippars = choice (map try [parseOIF, parseNH ippars, parseMetric, ignoreScope, ignoreProto, ignoreSrc ippars])

parseOpts :: Isabelle.Len a => Parsec String s (Isabelle.Word a) -> Parsec String s (Routing_rule a -> Routing_rule a)
parseOpts ippars = flip (foldl (flip id)) <$> many (parseOpt ippars <* skipWS)

litornat l =  (void $ nat) <|> void (choice (map lit l))

parseBlackhole :: Isabelle.Len a => Parsec String s (Routing_rule a -> Routing_rule a)
parseBlackhole = do
    lit "blackhole"
    skipWS
    return $ routing_action_oiface_update "!blackhole"

ignoreScope = do
    lit "scope"
    skipWS
    litornat ["host", "link", "global"]
    return id

ignoreProto = do
    lit "proto"
    skipWS
    litornat ["kernel", "boot", "static", "dhcp"]
    return id

ignoreSrc ippars = do
    lit "src"
    skipWS
    ippars
    return id

parseOIF :: Isabelle.Len a => Parsec String s (Routing_rule a -> Routing_rule a)
parseOIF = do
    lit "dev"
    skipWS
    routing_action_oiface_update <$> siface

parseNH ippars = do
    lit "via"
    skipWS
    routing_action_next_hop_update <$> ippars

parseMetric :: Isabelle.Len a => Parsec String s (Routing_rule a -> Routing_rule a)
parseMetric = do
    lit "metric"
    skipWS
    metric_update . const . Isabelle.nat_of_integer <$> nat

rTblToIsabelle (RTbl t) = t

instance Show (RTbl Word32) where
    show (RTbl t) = unlines . map show $ t
instance Show (RTbl Word128) where
    show (RTbl t) = unlines . map show $ t

{- now, for some code duplication... -}
skipWS = void $ many $ oneOf " \t"
lit str = (string str)
ipaddrOrCidr ippars = try (Isabelle.PrefixMatch <$> (ippars <* char '/') <*> (Isabelle.nat_of_integer <$> nat))
             <|> try (flip Isabelle.PrefixMatch (Isabelle.nat_of_integer 32) <$> ippars)
siface = many1 (oneOf $ ['A'..'Z'] ++ ['a'..'z'] ++ ['0'..'9'] ++ ['+', '*', '.', '-'])

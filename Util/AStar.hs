
import qualified Data.HashMap.Strict as H
import qualified Data.HashSet as HS

import Data.Hashable (Hashable (hashWithSalt))
import qualified Data.PSQueue as Q
import Data.PSQueue (Binding ((:->)))
import Data.Foldable (foldl')
import Data.Maybe (fromJust)

data Node a = Node a (Maybe (Node a))

value :: Node a -> a
value (Node a _) = a

-- explicit Eq and Hashable implementations to avoid recursive calls

instance Eq a => Eq (Node a) where
  (Node a Nothing) == (Node b (Just _)) = False
  (Node a (Just _)) == (Node b Nothing) = False
  (Node a Nothing) == (Node b Nothing)  = a == b
  (Node a (Just n1)) == (Node b (Just n2)) = a == b && value n1 == value n2

instance Hashable a => Hashable (Node a) where
    hashWithSalt s (Node a Nothing) = s `hashWithSalt` a
    hashWithSalt s (Node a (Just n)) = s `hashWithSalt` a `hashWithSalt` value n

instance Ord a => Ord (Node a) where
    compare (Node a _) (Node b _) = compare a b

data AStar a = AStar {
    getStart :: a,
    getGoal :: a -> [a] -> Bool,
    getCost :: a -> a -> Int,
    getNeighbours :: a -> [a] -> [a],
    getHeuristic :: a -> Int
}

type Score a = H.HashMap (Node a) Int
type PriorityQueue a = Q.PSQ (Node a) Int
type ClosedSet a = HS.HashSet (Node a)

path :: (Eq a, Hashable a, Ord a) => AStar a -> [a]
path astar =
    if immediatelyDone then [start] else path' astar gScore fScore openSet closedSet
    where start = getStart astar
          cost = getCost astar
          heuristic = getHeuristic astar start
          startNode = Node start Nothing
          immediatelyDone = getGoal astar start [start]
          gScore = H.singleton startNode 0
          fScore = H.singleton startNode heuristic
          openSet = Q.singleton startNode heuristic
          closedSet = HS.empty

path' :: (Eq a, Hashable a, Ord a) => AStar a -> Score a -> Score a -> PriorityQueue a -> ClosedSet a -> [a]
path' astar gScore fScore openSet closedSet
  | Q.null openSet = []
  | goal (value current) path = reverse (value current : path)
  | otherwise = path' astar gScore'' fScore'' openSet'' closedSet'
  where
      goal = getGoal astar
      cost = getCost astar
      neighbours = getNeighbours astar
      heuristic = getHeuristic astar
      (current :-> _, openSet') = fromJust $ Q.minView openSet
      path = getPath current
      closedSet' = HS.insert current closedSet
      score = gScore H.! current
      gScore' = H.delete current gScore
      fScore' = H.delete current fScore
      neighboursNodes =  filter (\n -> not (HS.member n closedSet)) $ map (\ x -> Node x (Just current))  (neighbours (value current) path)
      getPath (Node _ Nothing) = []
      getPath (Node _ (Just n)) = value n : getPath n
      tentatives = map (\n -> (n, score + cost (value current) (value n))) neighboursNodes
      (gScore'', fScore'', openSet'') = foldl' (\(gs, fs, os) (n, tentative) ->
        if tentative < H.lookupDefault (maxBound :: Int) n gs
        then (H.insert n tentative gs, H.insert n (tentative + heuristic (value n)) fs, Q.insert n (tentative + heuristic (value n)) os)
        else (gs, fs, os)) (gScore, fScore, openSet) tentatives
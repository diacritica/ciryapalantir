import networkx as nx
import re, json
import click

# this board does match size and potential londi
t= """{
   "size": 5,
   "board": {
        "a": {
            "2": ["C2"],
            "3": ["C2"],
            "4": ["C1", "C1"]
        },
        "b": {
            "2": ["C2"],
            "3": ["T2"],
            "4": ["C1"]
        },
        "c": {
            "2": ["C2"],
            "3": ["H2"],
            "4": ["C1"]
        },
        "d": {
            "3": ["C2"],
            "4": ["H1"]
        },
        "e": {
            "3": ["C2"],
            "4": ["C1"]
        }
    }
}"""

# this board doesn't match size and potential londi
t2= """{
   "size": 5,
   "board": {
        "a": {
            "2": ["C2"],
            "3": ["C2"],
            "4": ["C1", "C1"]
        },
        "b": {
            "2": ["C2"],
            "3": ["T2"],
            "4": ["C1"]
        },
        "c": {
            "2": ["C2"],
            "3": ["H2"],
            "4": ["C1"]
        },
        "d": {
            "3": ["C2"],
            "4": ["H1"]
        }
    }
}"""

def boardToMatrix(boardstatus):
    """
    This method takes a board json description and translates it into a matrix
    This matrix (list of lists) has 0 for no valid piece for Londë, 
    1 for Player1 valid piece for Londë, 2 for Player2 valid piece for Londë
    Careful, cols ans rows are swapped during this process.
    """
    
    boardrows = boardstatus.keys()
    size = len(boardrows)
    matrix = []
    acolumn = []

    for j in range(0, size):
        acolumn.append(0)
    for i in range(0, size):
        matrix.append(acolumn[:])
    
    newkeys = range(size)
    newrows = map(lambda x, y: (x, y), boardrows, newkeys)

    for nr in list(newrows):
        boardstatus[nr[1]] = boardstatus.pop(nr[0])

        for col in boardstatus[nr[1]].items():
            default = 0

            if col[1][-1].startswith("C") or col[1][-1].startswith("H"):
                player = col[1][-1][-1]
                boardstatus[nr[1]][col[0]] = int(player)
            else:
                boardstatus[nr[1]][col[0]] = default

    for r in boardstatus.keys():
        for c in boardstatus[r].items():
            matrix[r][int(c[0])-1] = c[1]

    return matrix

def normalizePath(listofpaths):
    """
    Unswaps paths and reflects coherent Cirya row,col notation
    """

    notationrows = {0:"a",1:"b",2:"c",3:"d",4:"e",5:"f",6:"g",7:"h",8:"i"}
    
    normalizedpaths = []
    for path in listofpaths:
        for i in range(len(path)):
            
           y = path[i][0]+1
           x = notationrows[path[i][1]]
           path.pop(i)
           path.insert(i,(x,y))
        normalizedpaths.append(path)

    return normalizedpaths

def getLondi(matrix, player=1):
    size = len(matrix)
    G=nx.Graph()
    nodes = []
    for i in range(len(matrix)):
        for j in range(len(matrix[i])):
            x = matrix[i][j]
            if x == player:
                xnode = (i,j)
                G.add_node(xnode)

                # try north adyacent
                try:
                    n = matrix[i][j+1]
                    nnode = (i,j+1)
                    if n == player:
                        G.add_node(nnode) 
                        G.add_edge(xnode,nnode)
                except:
                    pass

                # try south adyacent
                try:
                    if j > 0:
                        s = matrix[i][j-1]
                        snode = (i,j-1)
                        if s == player:
                            G.add_node(snode) 
                            G.add_edge(xnode,snode)
                except:
                    pass

                # try west adyacent
                try:
                    if i > 0:
                        w = matrix[i-1][j]
                        wnode = (i-1,j)
                        if w == player:
                            G.add_node(wnode) 
                            G.add_edge(xnode,wnode)
                except:
                    pass

                # try east adyacent
                try:
                    e = matrix[i+1][j]
                    enode = (i+1,j)
                    if e == player:
                        G.add_node(enode) 
                        G.add_edge(xnode,enode)
                except:
                    pass

    
    allpossiblelondi = [[(i,0),(j,size-1)] for i in range(size) for j in range(size)] + [[(0,i),(size-1,j)] for i in range(size) for j in range(size)]
    allpossiblelondi.remove([(0, 0), (size-1, size-1)])
    allpossiblelondi.remove([(0, size-1), (size-1, 0)])

    londi = []
    for i in allpossiblelondi:
        try:
           res = list(nx.all_simple_paths(G,i[0],i[1]))
           if res != []:
               londi += normalizePath(res)
        except:
            pass
    return(londi)



def check(jsonboard):

    boardjson = json.loads(jsonboard)
    size = boardjson["size"]
    boardstatus = boardjson["board"]

    if len(boardstatus.keys()) != size:
        return(json.dumps({"wcl":[],"bcl":[]}))

    else:
        matrix = boardToMatrix(boardstatus)
        
        whitelondi = getLondi(matrix, player=1)

        blacklondi = getLondi(matrix, player=2) 

        return(json.dumps({"wcl":whitelondi,"bcl":blacklondi}))


@click.command()
@click.option("-b","--board", prompt="Input board file", default="testboard.cb", show_default=True, help="Input path to a valid Cirya board file")

def run(board):

    with open(board, "r") as boardfile:
        boardjson = json.loads(boardfile.read())

    size = boardjson["size"]
    boardstatus = boardjson["board"]
    
    if len(boardstatus.keys()) != size:
        click.echo("Error, board format and board size do not match")

    else:
        matrix = boardToMatrix(boardstatus)
        print("Matrix >", matrix)
        
        whitelondi = getLondi(matrix, player=1)
        print("White", whitelondi)

        blacklondi = getLondi(matrix, player=2) 
        print("Black", blacklondi)


if __name__=="__main__":

    run()

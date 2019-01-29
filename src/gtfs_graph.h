#ifndef GTFSGRAPH_H
#define GTFSGRAPH_H

#include <vector>
#include <limits>

class GTFSGraphEdge {
    public:
        unsigned int source, target;
        int dist;
        GTFSGraphEdge *nextOut, *nextIn;
};

class GTFSGraphVertex {
    public:
        GTFSGraphEdge *outHead, *outTail;
        GTFSGraphEdge *inHead, *inTail;
        int outSize, inSize;
};

class GTFSGraph {
    public:
        GTFSGraph(unsigned int n);
        ~GTFSGraph();
        
        unsigned int nVertices() const;
        const std::vector <GTFSGraphVertex>& vertices() const;
        
        // disable copy/assign as will crash (double-delete)
        GTFSGraph (const GTFSGraph&) = delete;
        GTFSGraph& operator=(const GTFSGraph&) = delete;
    
        void clear();
        void addNewEdge (unsigned int srcVertex, unsigned int destVertex,
                int dist);
    private:
        void initVertices();
    
        std::vector <GTFSGraphVertex> m_vertices;
  
};


/*---------------------------------------------------------------------------*/
#endif

#include "gtfs_graph.h"

#include <Rcpp.h>
//#include <cstdio>

GTFSGraph::GTFSGraph (unsigned int n) : m_vertices(n)
{
    initVertices();
}

GTFSGraph::~GTFSGraph()
{
    clear();
}

unsigned int GTFSGraph::nVertices() const
{
  return static_cast <unsigned int> (m_vertices.size());
}

const std::vector<GTFSGraphVertex>& GTFSGraph::vertices() const
{
  return m_vertices;
}

void GTFSGraph::clear()
{
    GTFSGraphEdge *edge, *nextEdge;
    for(unsigned int i = 0; i < m_vertices.size(); i++) {
        edge = m_vertices[i].outHead;

        while(edge) {
            nextEdge = edge->nextOut;
            delete edge;
            edge = nextEdge;
        }
    }
    initVertices();
}

void GTFSGraph::initVertices()
{
    for(unsigned int i = 0; i < m_vertices.size(); i++) {
        m_vertices[i].outHead = m_vertices[i].outTail = nullptr;
        m_vertices[i].inHead = m_vertices[i].inTail = nullptr;
        m_vertices[i].outSize = m_vertices[i].inSize = 0;
    }
}

void GTFSGraph::addNewEdge(unsigned int source, unsigned int target,
        double dist, double wt)
{
    GTFSGraphEdge *newEdge = new GTFSGraphEdge;
    newEdge->source = source;
    newEdge->target = target;
    newEdge->dist = dist;
    newEdge->wt = wt;
    newEdge->nextOut = nullptr;
    newEdge->nextIn = nullptr;

    GTFSGraphVertex *vertex = &m_vertices[source];
    if(vertex->outTail) {
        vertex->outTail->nextOut = newEdge;
    }
    else {
        vertex->outHead = newEdge;
    }
    vertex->outTail = newEdge;
    vertex->outSize++;

    vertex = &m_vertices[target];
    if(vertex->inTail) {
        vertex->inTail->nextIn = newEdge;
    }
    else {
        vertex->inHead = newEdge;
    }
    vertex->inTail = newEdge;
    vertex->inSize++;
}

bool GTFSGraph::edgeExists(unsigned int v, unsigned int w) const
{
    const GTFSGraphEdge *edge = m_vertices[v].outHead;
    while(edge) {
        if(edge->target == w) return true;
        edge = edge->nextOut;
    }
    return false;
}

bool GTFSGraph::reachable (unsigned int s) const
{
    std::vector<unsigned int> stack(m_vertices.size());
    unsigned int tos = 0;

    std::vector<unsigned int> visited(m_vertices.size(), 0);

    unsigned int vertexCount = 0;
    visited [s] = 1;
    stack [tos++] = s;
    GTFSGraphEdge *edge;
    unsigned int v, w;
    while (tos) {
        v = stack [--tos];
        vertexCount++;
        edge = m_vertices [v].outHead;
        while (edge) {
            w = edge->target;
            if (!visited [w]) {
                visited [w] = 1;
                stack [tos++] = w;
            }
            edge = edge->nextOut;
        }
    }

    return vertexCount == m_vertices.size();
}

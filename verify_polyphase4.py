#!/usr/bin/env python3
import itertools, random, math

def jordan(seq):
    z0=z1=z2=0
    for x in seq:
        z0,z1,z2=z0+x,z1+z0,z2+z1
    return z0,z1,z2

def local_moments_from_jordan(z,m):
    if m==0: return (0,0,0)
    z0,z1,z2=z
    a=m-1
    s0=z0
    s1=a*s0-z1
    s2=2*z2+(2*a-1)*s1-(a*a-a)*s0
    return s0,s1,s2

def poly_cert(seq,W=4):
    return tuple(tuple(sum((k**d)*x for k,x in enumerate(seq[r::W])) for d in range(3)) for r in range(W))

def reconstruct(seq,W=4):
    loc=[]
    for r in range(W):
        ph=seq[r::W]
        loc.append(local_moments_from_jordan(jordan(ph),len(ph)))
    a0=sum(x[0] for x in loc)
    a1=sum(W*x[1]+r*x[0] for r,x in enumerate(loc))
    a2=sum(W*W*x[2]+2*W*r*x[1]+r*r*x[0] for r,x in enumerate(loc))
    return a0,a1,a2

def direct(seq):
    return sum(seq),sum(i*x for i,x in enumerate(seq)),sum(i*i*x for i,x in enumerate(seq))

random.seed(1)
for n in range(1,129):
    for _ in range(200):
        seq=[random.randrange(256) for _ in range(n)]
        assert reconstruct(seq)==direct(seq)
print("PASS: exact 4-phase reconstruction for 25,600 random sequences")

alphabet=range(3); n=8; cases=0
for seq in itertools.product(alphabet,repeat=n):
    base=poly_cert(seq)
    for t in range(1,4):
        for pos in itertools.combinations(range(n),t):
            replsets=[[v for v in alphabet if v!=seq[p]] for p in pos]
            for repl in itertools.product(*replsets):
                y=list(seq)
                for p,v in zip(pos,repl): y[p]=v
                cases+=1
                assert poly_cert(y)!=base
    for i in range(n-1):
        if seq[i]!=seq[i+1]:
            y=list(seq); y[i],y[i+1]=y[i+1],y[i]
            cases+=1
            assert poly_cert(y)!=base
print(f"PASS: {cases:,} exhaustive ternary mutation cases, no <=3-sub or adjacent-swap collision")

# Sharp 4-substitution collision in one phase r=0 at positions 0,4,8,12.
x=[0]*13; y=[0]*13
for p,v in zip([0,4,8,12],[1,0,3,0]): x[p]=v
for p,v in zip([0,4,8,12],[0,3,0,1]): y[p]=v
assert x!=y and poly_cert(x)==poly_cert(y)
print("PASS: explicit sharp 4-substitution same-phase collision verified")

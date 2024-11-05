---
title: "PRACTICE REPORT, BGP CONFIGURATION GUIDE"
author: ["daniel.juarez@iteso.mx, enrique.rios@iteso.mx", "TEAM 5"]
date: "2024-10-24"
subject: "Markdown"
keywords: [Markdown, Example]
subtitle: "ADVANCED ROUTING"
lang: "en"
titlepage: true
titlepage-color: "FFFFFF"
titlepage-text-color: "000000"
titlepage-rule-color: "DC143C"
titlepage-rule-height: 2
book: true
classoption: oneside
code-block-font-size: \scriptsize
toc: true
---

# EXECUTIVE REPORT

## PROJECT OVERVIEW

In this project, I delved into the intricacies of BGP multi-homing and its configuration in a simulated environment. Through the process of setting up and optimizing routing between multiple routers, I gained hands-on experience with eBGP and iBGP, which has significantly enhanced my understanding of how BGP functions in real-world scenarios. Working with route maps, local preference, and the MED attribute allowed me to see firsthand how routing decisions are made and influenced. This practical experience not only solidified my theoretical knowledge but also equipped me with the skills necessary to address real-life networking challenges. Engaging in this type of activity has deepened my appreciation for the complexities of network design and the critical thinking required to implement effective solutions.

### GOALS

- To perform the necessary configuration in the FOUR routers to achieve IPv4 routing convergence using BGP multi-homing based on the topology shown in the next BGP2 Diagram.

# BGP CONFIGURATION GUIDE REPORT

## BGP CONFIGURATION GUIDE

### NETWORK DIAGRAM

![BGP2 Diagram](image.png)


### CONFIGURATION OF BGP ON THE PROVIDERS

- The **Provider_SF** and **Provider_NY** are already configurated with IBGP between them, so we only need to enable the BGP conection with the client, this is solved by setting the eBGP configuration, where a connection is established between the provider (AS 65000) and the customer (AS 65001):

- **Provider_SF**
```cpp
Provider_SF(config)#router bgp 65000
Provider_SF(config-router)#neighbor 192.168.1.2 remote-as 65001
```
Here we are setting that Provider _SF is part of the AS 650000 and a neighbor on **192.168.1.2** thar is part of the AS 65001

- **ProviderNY**
```cpp
Provider_NY(config)#router bgp 65000
Provider_NY(config-router)#neighbor 192.168.2.2 remote-as 65001
```
Here we are setting that Provider _NY is part of the AS 650000 and a neighbor on **192.168.2.2** that is part of the AS 65001


### CONFIGURATION OF BGP ON THE COSTUMERS

- The Costumers routers **Cust1_SF** and **Cust1_NY** need to be configured for both eBGP and iBGP.
  - eBGP because the cosutmers need to have a conection with the providers routers.
  - iBGP because the costuers router needs to communicate between them, because they belong to the same AS.

- **Cust1_SF**
```cpp
Cust1_SF(config)#router bgp 65001
Cust1_SF(config-router)#network 192.168.10.0
```
Here we are setting that **Cust1_SF** is part of the AS 65001 and announce the network **192.168.10.0** to the AS itself and the providers.

```cpp
Cust1_SF(config-router)#neighbor 192.168.1.1 remote-as 65000
```
Here we are setting a connection by eBGP on **192.168.1.1** to the AS 65000 for the exchange of routes.

```cpp
Cust1_SF(config-router)#neighbor 192.168.3.2 remote-as 65001
```
Here we are setting a iBGP conection between all the member of the AS 65001 that are: **Cust1_SF** and **Cust1_NY**.

```cpp
Cust1_SF(config-router)#neighbor 192.168.3.2 next-hop-self
```
This command ensures that when **Cust1_SF** sends routes to **Cust1_NY**, **Cust1_SF** will establish its ip as the next hop to avoid a street with holes.



- **Cust1_NY**
```cpp
Cust1_NY(config)#router bgp 65001
Cust1_NY(config-router)#network 192.168.20.0
```
Here we are setting that **Cust1_NY** is part of the AS 65001 and announce the network **192.168.20.0** to the AS itself and the providers.

```cpp
Cust1_NY(config-router)#neighbor 192.168.2.1 remote-as 65000
```
Here we are setting a connection by eBGP on **192.168.2.1** to the AS 65000 for the exchange of routes.

```cpp
Cust1_NY(config-router)#neighbor 192.168.3.1 remote-as 65001
```
Here we are setting a iBGP conection between all the member of the AS 65001 that are: **Cust1_SF** and **Cust1_NY**.

```cpp
Cust1_NY(config-router)#neighbor 192.168.3.1 next-hop-self
```
This command ensures that when **Cust1_NY** sends routes to **Cust1_SF**, **Cust1_NY** will establish its ip as the next hop to avoid a street with holes.



### CONFIGURATION GUIDE OF THE PREFIX-LIST, ROUTE-MAPS AND PREFERENCE LOCAL ATTRIBUTE

- **Note:** If both routes have the same value for all attributes, the only difference is the way they have been learnt: internal (iBGP) and external (eBGP), then The BGP decision process picks the external one: this is the rule. 

- Now the goal is to reach the Providers subnets but with the restriction that C2 and C3 subnets needs to be reach by SF provider’s router, C4 and C5 subnets needs to be reach by NY provider’s router, for this we need to declare the prefix-lists.

- **Cust1_SF**
```cpp
ip prefix-list C2 seq 5 permit 10.1.1.0/24
ip prefix-list C3 seq 5 permit 10.1.2.0/24
!
route-map EBGP-With-ProviderSF_IN permit 10
 match ip address prefix-list C2 C3
 set local-preference 300
route-map EBGP-With-ProviderSF_IN permit 20
 set local-preference 200
!
router bgp 65001
 neighbor 192.168.1.1 route-map EBGP-With-ProviderSF_IN in
```

- **Cust1_NY**
```cpp
ip prefix-list C4 seq 5 permit 10.2.1.0/24
ip prefix-list C5 seq 5 permit 10.2.2.0/24
!
route-map EBGP-With-ProviderNY_IN permit 10
 match ip address prefix-list C4 C5
 set local-preference 300
route-map EBGP-With-ProviderNY_IN permit 20
 set local-preference 250
!
router bgp 65001
 neighbor 192.168.2.1 route-map EBGP-With-ProviderNY_IN in
```

### CONFIGURATION GUIDE OF THE MED ATTRIBUTE

- But there is a problem on the previous section, the LocalPref attrubute only influence the subnets locally on the AS, but that is the reason why for example the subnets of **Cust1_SF** prefers the way througth **Cust1_NY** even if that is the worst route, so we need to declare much more thing that that influence outside the AS. 

## TESTING CONFIGURATIONS

### ROUTE TRACING BETWEEN ...



### ROUTING TABLES



## CONCLUSIONS

**Juarez Mota Daniel Alejandro:** 

**Rios Gomez Jose Enrique:** Completing this BGP multi-homing project has been a rewarding experience that has deepened my understanding of advanced routing concepts. The hands-on nature of configuring BGP on various routers helped solidify my knowledge and provided me with valuable insights into the practical applications of these concepts. I enjoyed overcoming challenges like establishing proper routing relationships and optimizing route selections through Local Preference and MED adjustments. This experience has not only bolstered my technical skills but has also reinforced my passion for networking and the continuous learning that comes with it. I look forward to applying what I've learned in future projects and further expanding my knowledge in this field.


## REFERENCES
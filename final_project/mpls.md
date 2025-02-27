---
title: "PRACTICE REPORT, MPLS L3 VPN IMPLEMENTATION"
author: ["daniel.juarez@iteso.mx, enrique.rios@iteso.mx", "TEAM 5"]
date: "2024-11-24"
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

**MPLS Layer 3 VPN** is a networking solution designed to connect multiple customer sites over a shared service provider backbone, enabling secure and efficient communication. This technology uses **Multiprotocol Label Switching (MPLS)** to forward packets based on labels rather than IP addresses, ensuring faster routing and traffic isolation. Each customer network operates within a Virtual Routing and Forwarding (VRF) instance, which provides a dedicated routing table, maintaining privacy and preventing overlap between different customers.

In an MPLS L3 VPN, **Provider Edge (PE)** routers add and remove labels from packets as they enter or leave the MPLS backbone, while **Provider (P)** routers forward packets based solely on labels. Labels are distributed using the **Label Distribution Protocol (LDP)**. BGP plays a crucial role by exchanging VPN routing information between PE routers and associating routes with unique Route Distinguishers (RDs) to differentiate customers.

This approach provides several benefits, including simplified network management, scalability to support numerous VPNs, and robust Quality of Service (QoS) capabilities. MPLS L3 VPNs also enable seamless integration of different traffic types, such as voice, video, and data, over a unified infrastructure.  

This document outlines the configuration and testing of an MPLS L3 VPN where OSPF is used as the IGP within the provider's backbone, and BGP handles customer route exchanges. The implementation ensures that customer traffic remains isolated and routing tables are securely partitioned using VRFs, providing a scalable and high-performance solution for enterprise connectivity.

### GOALS

- Isolate customer traffic using VRFs and Route Distinguishers **(RDs)**.

- Enable efficient routing and forwarding through MPLS and Label Distribution Protocol **(LDP)**.

- Implement Border Gateway Protocol **(BGP)** to manage customer routing and enable scalability.

- Validate end-to-end connectivity and adherence to best practices.

# MPLS L3 VPN IMPLEMENTATION REPORT

### ASSUMPTIONS

- Provider's mesh implements **OSPF** as its IGP to enable further **iBGP** communication.
- Provider's backbone implements authentication (passwords are encrypted). 
- All customers share blocks between their sites by an **eBGP** tunnel between their providers.

### NETWORK DIAGRAM

![](mpls.png)

### LDP CONFIGURATION

Packet forwarding trough the provider's backbone must be done by using **LDP** by enabling **MPLS**. Packet labeling will begin once a packet located at any of the **PEs** routers reaches the interface facing provider's network. **MPLS** will be configured ONLY on those interfaces inside the provider's area, no **MPLS** related configurations must be done on the customer's side.

To enable **MPLS**, perform the following command:

```bash
in <INTERFACE FACING PROVIDER BACKBONE>
mpls ip
```

Where the above command will enable **LDP** on a specific interface.

- To hide the provider's mesh from traceroutes, the following command must be specified in the router's global config. This command will prevent the MPLS label to contain a copy of the actual TTL value from the ip packet:

```bash
no mpls ip propagate ttl
```

### VRFs CONFIGURATION

To avoid having a global routing table and to enable a separated and private routing tables for each customer, a network administrator can create a **VRF** (Virtual Routing Forwarding) where each route and traffic belonging to each of those routes will be identified by the **RD** (Route Designation) tag. 

- To enable **RD** tagging, run the following commands in the global config mode:

```bash
ip vrf <VRF NAME>
rd <PE AS>:<VRF ID> 
route-target <PE AS>:<VRF ID>
```

Where the above command will create a separated routing table identified by the name <VRF NAME> and will add the **RD** tag <PE AS>:<VRF ID>. 

- Just as **LDP**, tagging will happen only on those interfaces where it is specified. Enable the specific **RD** tag for each customer with the following directive. Once the command is ran, it will delete the interface's ip, so it requires to configure it again:

```bash
in <INTERFACE FACING CUSTOMER>
ip vrf forwarding <VRF NAME>
```

Consider the image below:

![](image.png)

In this case, **PE-R4** has defined two **VRFs** **CUST-A** and **CUST-B**, each one with a corresponding tag of **400:1** and **400:2**. To enable **CUST-A** and **CUST-B** tagging, interfaces **f0/1** and **f1/0** must have the following commands:

```bash
interface FastEthernet0/1
 ip vrf forwarding CUST-A
 ip address 172.16.1.2 255.255.255.252
 duplex auto
 speed auto
!
interface FastEthernet1/0
 ip vrf forwarding CUST-B
 ip address 172.16.3.2 255.255.255.252
 duplex auto
 speed auto
!
```

in all **PEs** routers, **eBGP** configurations will be different as it is required to have separated tables for each updates that come from different customers. 

- join updates from certain source to a **VRF** in the BGP process as follows:

```bash
address-family ipv4 vrf <VRF NAME>
neighbor <NEIGHBOR IP> remote-as <AS>
neighbor <NEIGHBOR IP> activate
```

In the project's scenario, this would be the command ran into the **BGP 400** process on the provider edge router:


```bash
!
 address-family ipv4 vrf CUST-B
  neighbor 172.16.3.1 remote-as 65100
  neighbor 172.16.3.1 activate
  no synchronization
 exit-address-family
 !
 address-family ipv4 vrf CUST-A
  neighbor 172.16.1.1 remote-as 65100
  neighbor 172.16.1.1 activate
  no synchronization
 exit-address-family
!
```

### BGP VPN CONFIGURATION

Once all **PE** customers have sent updates, and **PE** have leared them, those routes must be forwarding via **iBGP** configured between the rest of the **PEs**. In previous sections it has been mentioned IP packets will contain an **RD** tag. **BGP VPN** will enable **BGP** to make forwarding decisions based on the **RD** tag rather than the **IP**. 

- Enable the **BPG VPN** feature with the following command on the BGP process. BGP neighbors **must** have been already defined:

```bash
address-family vpnv4
neighbor <NEIGHBOR IP> activate
```

The following commands have been ran on the **PE** router from the above image:

```bash
!
 address-family vpnv4
  neighbor 10.255.255.5 activate
  neighbor 10.255.255.5 send-community extended
  neighbor 10.255.255.6 activate
  neighbor 10.255.255.6 send-community extended
 exit-address-family
!
```
 
### ALLOW RECEIVING BGP UPDATES FROM THE SAME AS

Once all have been configured the network administrator might find that all **PEs** are learning **BGP** updates correctly, but no updates can be seen on any of the customers. If the network administrator runs `debug ip bgp all updates` on any customer and resets the **BGP** process, the following message may appear[1]:

```bash
192.168.12.2 rcv UPDATE about 5.5.5.5/32 -- DENIED due to: AS-PATH contains our own AS;
```

Customers will refuse to learn any **BGP** updates since they come from the same **AS**, to avoid this error, run the following command on the customer's **BGP** process:

```bash
neighbor <PE> allowas-in
```

## TESTING CONFIGURATIONS

**INTERFACES ARE BASED ON THE FOLLOWING DIAGRAM:**

![](image-2.png)

### MPLS LABELING

![packet capture on f0/0 from R1 where MPLS header have been successfully added to ICMP packets](image-1.png)

### CUSTOMERS LEARNING THE CORRECT ROUTES

#### CUSTOMERS A

![CE-CustA-1](image-3.png)

![CE-CustA-2](image-5.png)

![CE-CustA-3](image-4.png)

#### CUSTOMERS B

![CE-CustB-1](image-6.png)

![CE-CustB-2](image-7.png)

### PEs GLOBAL ROUTING TABLE AND PRIVATE ROUTING TABLES

#### PE-R4

![global table](image-8.png)

![private table](image-12.png)

#### PE-R6

![global table](image-9.png)

![private table](image-13.png)

#### PE-R5

![global table](image-10.png)

![private tables](image-11.png)

### ICMP BETWEEN CUSTOMER A-A, B-B AND A-B

![ICMP between customers from CE-CustA-1](image-14.png)

![ICMP between customers from CE-CustB-1](image-15.png)

### TRACEROUTE BETWEEN CUSTOMER A-A

![three hops](image-16.png)

# CONCLUSIONS

**Juarez Mota Daniel Alejandro:** This practice allowed me to develop a solid understanding of how MPLS Layer 3 VPNs operate to provide secure and efficient communication between customer sites. I learned how VRFs and RDs work together to ensure traffic isolation and maintain unique routing tables for each customer. Configuring MPLS through LDP enabled me to see how packet labeling simplifies routing decisions within the provider's backbone, improving network performance. Additionally, I explored the role of BGP in exchanging customer routes and enabling the scalability of the VPN. I found it particularly interesting to configure and validate the end-to-end connectivity using Cisco commands and to see how traceroute behavior changes in MPLS environments. This exercise emphasized the importance of traffic separation and the operational benefits of MPLS in service provider networks.

**Rios Gómez José Enrique:** This project was an excellent opportunity to delve into the practical implementation of MPLS Layer 3 VPNs, and it has been one of the most rewarding experiences for me. I gained valuable insights into how MPLS enhances routing efficiency using labels, while VRFs ensure complete traffic isolation for different customers. The use of iBGP to exchange VPN routing information and the application of route targets to manage updates between PE routers clarified how MPLS achieves scalability and flexibility. I also appreciated learning about advanced features such as hiding the provider’s backbone from customer traceroutes and troubleshooting BGP updates using Cisco’s debug tools. This experience deepened my understanding of how service providers balance performance, scalability, and security to deliver high-quality VPN services, reinforcing my interest in network engineering.

# REFERENCES

[1] “Radware Captcha Page,” Networklessons.com, 2024. https://networklessons.com/mpls/mpls-ldp-label-filtering-example (accessed Nov. 29, 2024).

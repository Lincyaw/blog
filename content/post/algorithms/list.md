---
title: "链表"
date: 2021-08-27T21:32:14+08:00
hidden: true
draft: false
categories:
    - 学习
tags: 
    - 算法
---

链表是一种基础的数据结构。其每个节点在内存中的地址不连续，访问某个节点必须从头结点开始逐个遍历节点，因此在链表中找到某个节点的时间复杂度是 O(n)。而插入、删除则仅仅需要 O(1) 的时间复杂度。

在解决链表相关的问题时，可能会用到以下方法：

1. **哨兵节点**
2. **双指针**
3. **翻转链表**

## 哨兵节点

哨兵节点通常是用于处理头结点为空的边界情况。可以简化链表的操作逻辑。

如[删除倒数第 k 个节点中](https://leetcode-cn.com/problems/SLwz0R/)，该输入的链表头可能为空，通过设置哨兵节点，可以简化逻辑。

```go
/**
 * Definition for singly-linked list.
 * type ListNode struct {
 *     Val int
 *     Next *ListNode
 * }
 */
func removeNthFromEnd(head *ListNode, n int) *ListNode {
    node := &ListNode{}
    node.Next = head
    l, r := node,node
    for i:=0; i<=n; i++ {
        r = r.Next
    }
    for r != nil {
        l = l.Next
        r = r.Next
    }
    l.Next = l.Next.Next
    return node.Next
}
```


## 双指针

双指针可以说是链表系列的重头戏。因为链表无法通过下标访问，因此最为常见的是利用两个指针（当然也可以使用两个以上的指针）进行解决相关的问题。包括但不限于：

- [删除倒数第 k 个节点中](https://leetcode-cn.com/problems/SLwz0R/)，使两个指针间隔 k 个节点，再将 r 节点移动至末尾，删除 l 节点。
- [链表中环的入口节点](https://leetcode-cn.com/problems/c32eOV/)，快慢指针找到一个环中的节点（不能保证是在环的入口，但一定能保证在环内）。
  - 设此时 l 节点走了 k 步，则 r 节点走了 2k 步，他们重合在环中的一个节点。
  - 设环之前的有 n 个节点，绕环一圈有 m 个节点。
  - 则可以得到 l 节点从环的起始点已经走了 `k-n ` 个节点，而 r 节点已经走了 `2k-n` 个节点，此时他们发生了重合，这意味着 `(2k-n)-(k-n)=m`，即 `k=m`，k 就是环的长度。
  - 则如果在链表头设置一个指针 p，让 p 和 l 以相同的速度在链表里走，则他们第一次相遇的地方就是环的入口节点。（因为链表头与 l 的距离也是 k）
- [两个链表的第一个重合节点](https://leetcode-cn.com/problems/3u1WK4/)，两个指针分别对应两个链表，同时走 。一个链表走结束之后走到另一个链表里。这样当两个指针重合时就是第一个重合的点。
  - 原理是，两个指针都走了相同的路程。

## 反转链表

反转链表的代码相当简洁：

```go
func reverseList(head *ListNode) *ListNode {
    if head == nil || head.Next == nil {
        return head
    }
    pre, cur := head, head.Next
    pre.Next = nil
    for cur!=nil {
        // pre的next指向cur，cur和pre向后挪一位
        cur.Next, pre, cur = pre, cur, cur.Next
    }
    return pre
}
```

其重要程度也可以从几个题目中体现出来。

- [链表中的两数相加](https://leetcode-cn.com/problems/lMSNwu/)，每个链表的每个节点代表一位数，要求把两个链表的代表的值加起来。通过模拟低位相加进位的方式可以做，则第一步是将两个链表翻转。
- [重排链表](https://leetcode-cn.com/problems/LGjMqU/)，双指针断开链表，分成一半一半。然后翻转后半部分的链表，再进行间隔插入。
- [回文链表](https://leetcode-cn.com/problems/aMhZSa/)，双指针断开链表，分成一半一半。然后翻转后半部分的链表，再进行逐个比较。

以上讨论的均是单向链表。双向链表、双向循环链表等道理都差不多，但是处理起来会更加麻烦一些，因为涉及到的指针操作更多了。
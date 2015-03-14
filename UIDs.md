# Introduction #

Here we talk about UIDs rather than UUIDs because we do not care about uniqueness beyond this application. If we wanted a UUID, then we would just prefix the UID with an application identifier...

Anything we want to refer to within the application, has a UID. This includes events, sessions, paragraphs, device codes, event types etc.

# Format #

The format of a UID is:

**{domain}:[{context}#]{local-id}**

where local-id has the format: **[{grouping}-]{sub-id}**

domain is one of: event-type|event|session|audio|video|image|device-code|markup-type|markup-category|concept|tape

context and grouping are both optional

So, expanded in full, the format of a UID is:

**{domain}:[{context}#][{grouping}-]{sub-id}**

Example: **event-type:n** (where domain = event-type, no context, no grouping, local-id/sub-id = n)

The regexp for each of these four components is:

`[a-z0-9]*([a-z0-9]\-[a-z0-9])*[a-z0-9]*`

(but not the empty string)

which is essentially saying that it contains any sequence of letters, digits and hyphens and that every hyphen is surrounded by letters/digits.

In situations where we do not have direct control over the UID (e.g. event, session), the sub-id is an incremental integer.

Where we do have direct control over the UID (event-type, device-code), the sub-id is a bit more descriptive (e.g. aud-1, topic)

Any local-id can be used as a context or grouping.

For example, an event's local-id (n-123) is used as the grouping value for sessions (n-123-1).

Also a session's local-id (n-123-1) is used as a context for segments.

# When do we make something a context, and when a grouping? #

There is grey line between context and grouping. The decision dictates what goes in the ID attribute (grouping does, context doesnt). Essentially, if something is likely to be used in isolation, then use groupings, otherwise use contexts. So, we use things like events, sessions and media in isolation, but markups and segments are always in the context of its transcript/session.

# Examples #

These are the main UIDs.

| | UID | | | local-id (part 1) | local-id (part 2) |
|:|:----|:|:|:------------------|:------------------|
|  |  | domain | context | grouping | sub-id |
| Event type | **event-type:n** | event-type |  |  | n |
| Event | **event:n-123** | event |  | n (event-type local-id)| 123 |
| Session | **session:n-123-1** | session |  | n-123 (event local-id) | 1 |
| Media | **audio:n-123** | audio (also video, image) |  | n (event-type local-id) | 123 |
| Device code | **device-code:aud-1** | device-code |  |  | aud-1 |
| Markup type | **markup-type:topic** | markup-type |  |  | topic |
| Markup category | **markup-category:pope-joke-1** | markup-category |  |  | pope-joke-1 |
| Concept | **concept:life** | concept |  |  | life |
| Segment | **segment:n-123-1#p1** | segment | n-123-1 (session local-id) |  | s1 |
| Content | **content:n-123-1#c1** | content | n-123-1 (session local-id) |  | c1 |
| Markup | **markup:n-123-1#o1** | markup | n-123-1 (session local-id) |  | m1 |
| Tape | **tape:1** | tape |  |  | 1 |

Note - the single-letter prefixes to s1, c1 and m1 are only there so that we have uniqueness of id attributes within a session document. Probably, in a UID, they should not be there at all because that iniformation is available from the domain. Problem is, we normally don't want to bother specifying the domain. In other words we would rather specify the id as: n-123-1#m1 than markup:n-123-1#1.  One way around this would be to group these three domains into one: session-fragment:n-123-1#m1.  Or even use the session domain: session:n-123-1#m1 in which case we should rewrite this document to allow for this different use of the "#" character.

Note - You may be wondering why "aud-1" is not split into two parts. This is because we never use "aud" as a logical grouping. "aud-1" and "aud-2" are considered no less different than "vid-1". Maybe later we decide that aud-1 and aud-2 are more similar, in which case we just split "aud" out as a grouping.

For similar reasons, markup-category also has no groupings.

` `

# Representation in XML #

In the XML we specify local-ids in the "@id" attributes. The domains are used as the element tag name. For example:

<event id="n-123" ...>

Referring to a UID we do something like:

<session ... eventId="n-123"> (for incremental sub-ids)
<device ... deviceCode="aud-1"> (for code-based sub-ids)

i.e. the domain is used in the attribute name and the local-id is attribute value

This is not strictly enforced. For example:

<event ... type="n">

should really be

<event ... eventType="n">

but who cares :)

Another inconsistency: the markup elements are named "superSegment" and "superContent" rather than "markup" - this is to assist queries and is not really a problem since superSegment and superContent are both types of markup.

Where there is a context component in the UID, this is always specified by way of the element being a descendant of some element representing that context. For example, the segment with local-id n-123-1#s1 is represented by an element (with @id = s1) that is a descendant of the session with local-id n-123-1.
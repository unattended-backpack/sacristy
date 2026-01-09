import { BigInt, Bytes, ByteArray, crypto } from "@graphprotocol/graph-ts"
import {
  Transfer as TransferEvent,
  NewOwner as NewOwnerEvent,
  NewResolver as NewResolverEvent,
  NewTTL as NewTTLEvent
} from "../generated/ENSRegistry/ENSRegistry"
import {
  AddrChanged as AddrChangedEvent,
  NameChanged as NameChangedEvent
} from "../generated/templates/Resolver/PublicResolver"
import { Resolver as ResolverTemplate } from "../generated/templates"
import {
  Domain,
  Account,
  Resolver,
  Transfer,
  NewOwner,
  NewResolver,
  NewTTL,
  AddrChanged,
  NameChanged
} from "../generated/schema"

const EMPTY_ADDRESS = "0x0000000000000000000000000000000000000000"

function createEventID(blockNumber: BigInt, logIndex: BigInt): string {
  return blockNumber.toString().concat("-").concat(logIndex.toString())
}

// Extract the first label from a name like "alice.eth" -> "alice"
function extractLabel(name: string): string | null {
  if (name.length == 0) {
    return null
  }
  let labels = name.split(".")
  if (labels.length > 0 && labels[0].length > 0) {
    return labels[0]
  }
  return null
}

// Compute ENS namehash for a name like "alice.eth"
function namehash(name: string): Bytes {
  // Use ByteArray for computation, convert to Bytes only at return
  let node = new ByteArray(32)
  node.fill(0)

  if (name.length == 0) {
    return Bytes.fromByteArray(node)
  }

  let labels = name.split(".")
  for (let i = labels.length - 1; i >= 0; i--) {
    let labelBytes = ByteArray.fromUTF8(labels[i])
    let labelHash = crypto.keccak256(labelBytes)
    node = crypto.keccak256(node.concat(labelHash))
  }

  return Bytes.fromByteArray(node)
}

function getOrCreateAccount(address: string): Account {
  let account = Account.load(address)
  if (account == null) {
    account = new Account(address)
    account.save()
  }
  return account
}

function getOrCreateDomain(node: string, timestamp: BigInt): Domain {
  let domain = Domain.load(node)
  if (domain == null) {
    domain = new Domain(node)
    domain.createdAt = timestamp
    // Ensure the empty account exists before referencing it
    let emptyAccount = getOrCreateAccount(EMPTY_ADDRESS)
    domain.owner = emptyAccount.id
    // BENS-required fields
    domain.subdomainCount = 0
    domain.isMigrated = true
  }
  return domain
}

export function handleTransfer(event: TransferEvent): void {
  let node = event.params.node.toHexString()
  let owner = event.params.owner.toHexString()

  let account = getOrCreateAccount(owner)
  let domain = getOrCreateDomain(node, event.block.timestamp)
  domain.owner = account.id
  // Set registrant same as owner for simpler ENS
  domain.registrant = account.id
  domain.save()

  let transferEvent = new Transfer(createEventID(event.block.number, event.logIndex))
  transferEvent.domain = domain.id
  transferEvent.blockNumber = event.block.number.toI32()
  transferEvent.transactionID = event.transaction.hash
  transferEvent.owner = account.id
  transferEvent.save()
}

export function handleNewOwner(event: NewOwnerEvent): void {
  let parentNode = event.params.node.toHexString()
  let label = event.params.label
  let owner = event.params.owner.toHexString()

  let subnode = crypto.keccak256(event.params.node.concat(label)).toHexString()

  let account = getOrCreateAccount(owner)
  let parentDomain = getOrCreateDomain(parentNode, event.block.timestamp)
  let domain = getOrCreateDomain(subnode, event.block.timestamp)

  domain.owner = account.id
  domain.parent = parentDomain.id
  domain.labelhash = label
  // Set registrant same as owner for simpler ENS (no separate registrar)
  domain.registrant = account.id
  domain.save()

  // Increment parent's subdomain count
  parentDomain.subdomainCount = parentDomain.subdomainCount + 1
  parentDomain.save()

  let newOwnerEvent = new NewOwner(createEventID(event.block.number, event.logIndex))
  newOwnerEvent.domain = domain.id
  newOwnerEvent.parentDomain = parentDomain.id
  newOwnerEvent.blockNumber = event.block.number.toI32()
  newOwnerEvent.transactionID = event.transaction.hash
  newOwnerEvent.owner = account.id
  newOwnerEvent.save()
}

export function handleNewResolver(event: NewResolverEvent): void {
  let node = event.params.node.toHexString()
  let resolverAddr = event.params.resolver.toHexString()

  let domain = getOrCreateDomain(node, event.block.timestamp)

  if (resolverAddr != EMPTY_ADDRESS) {
    let resolver = new Resolver(resolverAddr.concat("-").concat(node))
    resolver.domain = domain.id
    resolver.address = event.params.resolver
    resolver.save()

    domain.resolver = resolver.id

    ResolverTemplate.create(event.params.resolver)
  } else {
    domain.resolver = null
  }

  domain.save()

  let newResolverEvent = new NewResolver(createEventID(event.block.number, event.logIndex))
  newResolverEvent.domain = domain.id
  newResolverEvent.blockNumber = event.block.number.toI32()
  newResolverEvent.transactionID = event.transaction.hash
  if (domain.resolver) {
    newResolverEvent.resolver = domain.resolver!
  }
  newResolverEvent.save()
}

export function handleNewTTL(event: NewTTLEvent): void {
  let node = event.params.node.toHexString()

  let domain = getOrCreateDomain(node, event.block.timestamp)
  domain.save()

  let newTTLEvent = new NewTTL(createEventID(event.block.number, event.logIndex))
  newTTLEvent.domain = domain.id
  newTTLEvent.blockNumber = event.block.number.toI32()
  newTTLEvent.transactionID = event.transaction.hash
  newTTLEvent.ttl = event.params.ttl
  newTTLEvent.save()
}

export function handleAddrChanged(event: AddrChangedEvent): void {
  let node = event.params.node.toHexString()
  let addr = event.params.addr.toHexString()

  let account = getOrCreateAccount(addr)

  // Update resolver entity if it exists
  let resolverId = event.address.toHexString().concat("-").concat(node)
  let resolver = Resolver.load(resolverId)
  if (resolver != null) {
    resolver.addr = account.id
    resolver.save()
  }

  // Get or create domain and set resolvedAddress
  // This ensures we capture resolution even if NewOwner hasn't been processed yet
  let domain = getOrCreateDomain(node, event.block.timestamp)
  domain.resolvedAddress = account.id
  domain.save()

  let addrChangedEvent = new AddrChanged(createEventID(event.block.number, event.logIndex))
  addrChangedEvent.resolver = resolverId
  addrChangedEvent.blockNumber = event.block.number.toI32()
  addrChangedEvent.transactionID = event.transaction.hash
  addrChangedEvent.addr = account.id
  addrChangedEvent.save()
}

export function handleNameChanged(event: NameChangedEvent): void {
  let node = event.params.node.toHexString()
  let name = event.params.name

  let resolverId = event.address.toHexString().concat("-").concat(node)

  // Extract label from name for BENS compatibility
  let label = extractLabel(name)

  // NameChanged is typically emitted on a reverse resolver when setting
  // a primary name for an address. We only want to set the name on the
  // forward domain (e.g., "pride.eth"), not on the reverse domain
  // (which would cause duplicates in the BENS domain list).

  // Update the forward domain with the name
  // e.g., if name is "alice.eth", compute namehash("alice.eth") and set name there
  if (name.length > 0) {
    let forwardNode = namehash(name).toHexString()
    let forwardDomain = Domain.load(forwardNode)
    if (forwardDomain != null && forwardDomain.name == null) {
      forwardDomain.name = name
      if (label != null) {
        forwardDomain.labelName = label
      }
      forwardDomain.save()
    }
  }

  let nameChangedEvent = new NameChanged(createEventID(event.block.number, event.logIndex))
  nameChangedEvent.resolver = resolverId
  nameChangedEvent.blockNumber = event.block.number.toI32()
  nameChangedEvent.transactionID = event.transaction.hash
  nameChangedEvent.name = name
  nameChangedEvent.save()
}

import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function main() {
  const ku = await prisma.user.findFirst({ where: { email: 'kitchen@banan.local' }, select: { email: true, role: true, kitchenId: true, storeId: true } });
  console.log('kitchen user:', JSON.stringify(ku));
  const stores = await prisma.store.findMany({ select: { slug: true, defaultKitchenId: true } });
  for (const s of stores) console.log('store:', s.slug, '| defaultKitchenId:', s.defaultKitchenId);
  const kitchens = await prisma.kitchen.findMany({ select: { id: true, name: true } });
  for (const k of kitchens) console.log('kitchen:', k.id, '|', k.name);
}
main().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>prisma.$disconnect());

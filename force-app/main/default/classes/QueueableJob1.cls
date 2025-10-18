public with sharing class QueueableJob1 extends TXS_QueueCtrl.QueueFactoryBase implements Queueable, TXS_QueueCtrl.IQueueFactory{
    
    public QueueableJob1(){}
    public QueueableJob1(TXS_QueueCtrl controller){
        keep(controller);
    }

    public void processQueue(){
        initQueue();
        processBatch();
        createLog();
    }

    public List<String> createFakeData(Integer size){
        List<String> fakeData = new List<String>();
        for(Integer i = 0; i <= size; i++){
            fakeData.add(String.valueOf(i));
        }

        return fakeData;
    }

    public void processBatch(){
        List<String> parcelIds = createFakeData(TXS_QueueCtrl.MAX_DATA_SIZE);
        // Process Batches
        String parcelIdsStr = JSON.serialize(parcelIds).removeStart('[').removeEnd(']');
        String currentItem = '', preItem = '';
        Integer totalTransactions = (Integer) Math.ceil(parcelIds.size()/(Double)TXS_QueueCtrl.MAX_CHUNK_SIZE), 
        totalExecutedRows = 0, preIndex = 0, currentIndex = 0;
        
        for(Integer index = 1; index <= totalTransactions; index++){
            
            totalExecutedRows = TXS_QueueCtrl.MAX_CHUNK_SIZE * index;
            currentItem = parcelIds[totalExecutedRows >= parcelIds.size() ? parcelIds.size() - 1 : totalExecutedRows];
            preItem = parcelIds[totalExecutedRows - TXS_QueueCtrl.MAX_CHUNK_SIZE];
            
            preIndex = parcelIdsStr.indexOf('"' + preItem + '"');
            currentIndex = totalExecutedRows < parcelIds.size() ? parcelIdsStr.indexOf('"' + currentItem + '"') : parcelIdsStr.length();

            String subIdsStr = parcelIdsStr.substring(preIndex, currentIndex).removeEnd(',');
            List<String> subParcelIds = (List<String>) JSON.deserialize(String.format('[{0}]', new List<String>{subIdsStr}), List<String>.class);
            loadChunk('', subParcelIds);
        }

        System.enqueueJob(new QueueableJob1(super.getController()));
    }

    public void execute(QueueableContext context){
        try {
            List<String> recordIds = super.next();
            System.debug(recordIds);
            super.remove(recordIds);

            if(super.hasNext()){
                System.enqueueJob(new QueueableJob1(super.getController()));
            } else {
                System.debug('End Queue');
            }
        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }
    }
}
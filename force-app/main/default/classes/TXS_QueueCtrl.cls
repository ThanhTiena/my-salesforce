public with sharing class TXS_QueueCtrl {

    // instance properties
    public String eventId;
    public List<String> errors;
    public QueueModel models;
    public static final Integer MAX_CHUNK_SIZE = 50;
    public static final Integer MAX_CONCURRENT_JOB = 5;
    public static final Integer MAX_DATA_SIZE = 20000;

    public interface IQueueFactory {
        void processQueue();
    }

    public virtual class QueueFactoryBase{
        
        private TXS_QueueCtrl queueController;

        public void initQueue(){
            System.debug('Init queue successfull');
            this.queueController = new TXS_QueueCtrl();
            this.queueController.eventId = '';
            this.queueController.models = new QueueModel();
            this.queueController.errors = new List<String>();
        }

        public void keep(TXS_QueueCtrl controller){
            this.queueController = controller;
        }

        public TXS_QueueCtrl getController(){
            return this.queueController;
        }

        public void loadChunk(String eventId, List<String> recordIds){   
            this.queueController.models.setEventId(eventId)
                                      .loadChunk(recordIds);
        }

        public void addErrors(List<String> errors){
            this.queueController.errors.addAll(errors);
        }

        public Boolean hasNext(){
            return this.queueController.models.hasNext();
        }

        public List<String> next(){
            return this.queueController.models.next();
        }

        public void remove(List<String> recordIds){
            this.queueController.models.removeChunk(recordIds);
        }

        public virtual void createLog(){
            System.debug(this.queueController.models);
            System.debug(String.join(this.queueController.errors, ', '));
        }
    }

    public class QueueFactoryManager{
        public QueueFactoryManager(){}

        public TXS_QueueCtrl.IQueueFactory instance(String queueName){
            Type t = Type.forName(queueName);
            return (TXS_QueueCtrl.IQueueFactory) t.newInstance();
        }
    }

    public class QueueModel{
        private String eventId;
        private Set<List<String>> batches;
        
        public QueueModel(){
            this.batches = new Set<List<String>>();
        }

        public String getEventId(){
            return this.eventId;
        }

        public QueueModel setEventId(String saleEventId){
            this.eventId = saleEventId;
            return this;
        }

        public QueueModel loadChunk(List<String> recordIds){
            this.batches.add(recordIds);
            return this;
        }

        public QueueModel removeChunk(List<String> recordIds){
            this.batches.remove(recordIds);
            return this;
        }

        public List<String> next(){
            return this.batches.iterator().next();
        }

        public Boolean hasNext(){
            return this.batches.iterator().hasNext();
        }
    }
}